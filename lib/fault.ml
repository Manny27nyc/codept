
module Level = struct
type t = int
let whisper = 0
let notification = 1
let warning = 2
let error = 3
let critical = 4

let of_int n = if n < whisper then
    whisper
  else if n > critical then
    critical
  else
    n

let of_string =
  function
  | "whisper" | "0" -> whisper
  | "notification" | "1" -> notification
  | "warning" | "2" -> warning
  | "error" | "3" -> error
  | "critical" | "4" -> critical
  | _ -> whisper
end

module Log = struct
let critical fmt =
  Format.kfprintf
  (fun _ppf -> exit 1) Format.err_formatter
    ("@[[\x1b[91mCritical error\x1b[39m]: @[<hov>"^^fmt^^"@]@]@.")

let error fmt =
  Format.eprintf @@
  "@[[\x1b[31mError\x1b[39m]: @[<hov>"^^fmt^^"@]@]@."

let warning fmt = Format.eprintf @@
  "@[<hov2>[\x1b[35mWarning\x1b[39m]:@,@ @[" ^^ fmt ^^ "@]@]@."

let notification fmt = Format.eprintf @@
  "@[<hov2>[\x1b[36mNotification\x1b[39m]:@,@ @[" ^^ fmt ^^ "@]@]@."

let whisper fmt = Format.eprintf @@
  "@[<hov2>[Misc]:@,@ @[" ^^ fmt ^^ "@]@]@."
end

type log_info = { silent:Level.t; level:Level.t; exit:Level.t}
let log {silent;level;exit} fmt =
  let fns = Log.[| whisper; notification; warning; error; critical |] in
  if level <= silent then Format.ifprintf Format.err_formatter fmt
  else if level >= min Level.critical exit then
    Log.critical fmt
  else
    fns.(level) fmt


let llog fmt = fun level -> log level fmt
let with_lvl f = fun lvl -> f lvl

type 'a fault = { path: Paths.S.t; log: log_info -> 'a }
type 'a t = 'a fault


(** Warnings *)
let extension =
{ path = ["extension"; "ignored"];
  log = (fun lvl (name, _)  ->
      log lvl "extension node %s ignored." name.Location.txt)
}

let  generic_first_class=
{ path = ["first_class";"gen"];
  log = llog "first-class modules are very partially handled for now."
}

let opened_first_class =
{ path = ["first_class"; "open"];
    log = (fun lvl ->
      log lvl "First-class module %s was opened while its signature was unknown."
      )
  }

let included_first_class =
  { path = ["first_class"; "included"];
    log =  llog "First-class module was included while its signature was unknown."
  }

let applied_structure =
  { path = ["typing"; "apply"; "structure"];
    log = (fun lvl -> log lvl "Only functor can be applied, got:%a"
               Module.Partial.pp)
  }

let signature_expected =
  { path = ["typing"; "signature_expected"];
    log = (fun lvl -> log lvl "A signature, i.e. not a functor was expected; got:%a"
               Module.Partial.pp)
  }


let applied_unknown =
  { path = ["typing"; "apply"; "unknown"];
    log = (fun lvl -> log lvl "Only functor can be applied, got:%a"
               Module.Partial.pp)
  }


let concordant_approximation =
  { path = ["parsing"; "approximation"; "concordant"];
    log = (fun lvl path -> log lvl
             "Approximate parsing of %a.\n\
              However, lower and upper bound agreed upon dependencies."
        Paths.P.pp path
           )
  }

let discordant_approximation =
  { path = ["parsing"; "approximation"; "discordant"];
    log = (fun lvl path lower diff -> log lvl
               "Approximate parsing of %a.\n\
                Computed dependencies: at least {%a}, maybe: {%a}"
        Paths.P.pp path
        Pp.(list string) lower
        Pp.(list string) diff
           )
  }


(** Syntax errors *)

let print_loc ppf loc =
  let (msg_file, msg_line, msg_chars, msg_to) =
  ("File \"", "\", line ", ", characters ", "-") in
  let open Location in
  let (file, line, startchar) = get_pos_info loc.loc_start in
  let endchar = loc.loc_end.pos_cnum - loc.loc_start.pos_cnum + startchar in
    Format.fprintf ppf "%s%a%s%i" msg_file print_filename file msg_line line;
    if startchar >= 0 then
      Format.fprintf ppf "%s%i%s%i" msg_chars startchar msg_to endchar

let syntaxerr =
  { path = ["parsing"; "syntax"];
    log = (fun lvl error ->
        log lvl "Syntax error\n %a" print_loc
          (Syntaxerr.location_of_error error)
      )
  }

module Polycy = struct
  type map = Level of Level.t | Map of Level.t * map Name.Map.t
  type t = { silent: Level.t; exit:Level.t; map:map}
  type polycy = t

  let rec find pol l  =
    match pol, l with
    | Level h, _ -> h
    | Map (h,m), a :: q  ->
      begin
        try find (Name.Map.find a m) q with
          Not_found -> h
      end
    | Map (h,_), [] -> h

  let find {map; _ } = find map

  let rec set (path,lvl) env = match path, env with
    | [], Level _ -> Level lvl
    | [], Map (_,m) -> Map(lvl,m)
    | a :: q, Level h ->
      Map(h, Name.Map.singleton a @@ set (q,lvl) @@ Level h)
    | a :: q, Map(h, m) ->
      let env' = try
          Name.Map.find a m with
      | Not_found -> Level h in
      let elt = set (q,lvl) env' in
      let m = Name.Map.add a elt m in
      Map(h, m)

  let set x p = { p with map = set x p.map }

  let set_err (error,lvl) polycy = set (error.path,lvl) polycy

  let strict = Level.{ silent = whisper; exit = critical ; map= Level critical }

  let default =
    strict
    |> set_err (applied_unknown, Level.warning )
    |> set (["first_class"], Level.warning )
    |> set (["extension"], Level.warning)

  let parsing_approx =
    default
    |> set (["parsing"], Level.warning)
    |> set_err (concordant_approximation, Level.notification)

  let lax =
    parsing_approx
    |> set (["typing"], Level.error)

  let quiet = { lax with silent = Level.error }

  end

let set = Polycy.set_err
let handle (polycy:Polycy.t) error =
  error.log {
    level =
      Polycy.find polycy error.path;
    silent = polycy.silent;
    exit = polycy.exit;
  }
