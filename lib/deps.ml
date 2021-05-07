
module Edge = struct
  type t = Normal | Epsilon
  let max x y = if x = Epsilon then x else y
  let min x y = if x = Normal then x else y

  let sch = let open Schematic in
    custom  (Sum["Normal", Void; "Epsilon", Void ])
      (function Normal -> C E | Epsilon -> C (S E))
      (function C E -> Normal | C S
           E -> Epsilon | _ -> . )
  let pp ppf = function
    | Normal -> Pp.fp ppf "N"
    | Epsilon -> Pp.fp ppf "ε"

end

module S = Namespaced.Set
type dep = { path: Namespaced.t; edge:Edge.t; pkg:Pkg.t; aliases:S.t}
type subdep = { edge:Edge.t; pkg:Pkg.t; aliases:S.t }
module Map = Namespaced.Map
type t = subdep Map.t

let sch: t Schematic.t =
  let module T = Schematic.Tuple in
  let from_list = let open T in
    List.fold_left
      (fun m [k; edge; pkg; aliases] -> Map.add k {edge;pkg;aliases} m)
      Map.empty in
  let to_list m =
    Map.fold (fun k {edge;pkg;aliases} l -> T.[k;edge;pkg;aliases] :: l) m [] in
  let open Schematic in
  custom (Array [Namespaced.sch; Edge.sch; Pkg.sch; S.sch])
    to_list from_list

module Pth = Paths.S
module P = Pkg

let empty = Map.empty

let update ~path ?(aliases=S.empty) ~edge pkg deps: t =
  let ep =
    let update x =
      let aliases = S.union aliases x.aliases in
      { x with edge = Edge.max edge x.edge; aliases } in
    Option.either update {edge;pkg; aliases }
      (Map.find_opt path deps) in
  Map.add path ep deps

let make ~path ?aliases ~edge pkg = update ~path ?aliases ~edge pkg empty

let merge =
  Map.union (fun _k x y ->
      let aliases = S.union x.aliases y.aliases in
      Some { y with edge = Edge.max x.edge y.edge; aliases })

let (+) = merge


let find path deps =
  Option.fmap (fun {edge;pkg;aliases} -> {path;edge;pkg;aliases}) @@ Map.find_opt path deps
let fold f deps acc =
  Map.fold (fun path {edge;pkg;aliases} -> f {path;edge;pkg;aliases}) deps acc

let pp_elt ppf (path, {edge;pkg;aliases}) =
  Pp.fp ppf "%s%a(%a)%a" (if edge = Edge.Normal then "" else "ε∙")
    Namespaced.pp path P.pp pkg S.pp aliases

let pp ppf s =
    Pp.fp ppf "@[<hov>{%a}@]" (Pp.list pp_elt) (Map.bindings s)

let of_list l =
  List.fold_left (fun m {path;edge;pkg;aliases} -> Map.add path {edge; pkg; aliases} m) empty l

let pkgs deps = fold (fun {pkg; _ } x ->  pkg :: x) deps []
let paths deps = fold (fun {path; _ } x ->  path :: x) deps []
let all deps = fold List.cons deps []
let pkg_set x = Map.fold (fun _ x s -> P.Set.add x.pkg s) x P.Set.empty
