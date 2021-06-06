type path = Transforms.answer
type query = path Transforms.query_result

type module_like
type m2l
type state_diff

type path_in_context = {
  loc : Uloc.t;
  edge : Deps.Edge.t option;
  level : Module.level;
  seed: Id.seed;
  ctx : state_diff;
  path : Paths.Simple.t;
  within: Module.signature option;
}

val pp: path_in_context Pp.t
val pp_ml: module_like Pp.t

val path: query -> path

(** Module like *)
val abstract : Id.seed -> module_like
val apply : Transforms.param -> Uloc.t -> f:module_like -> x:module_like  -> module_like
val unpacked : module_like
val fn : f:module_like -> x:module_like Module.Arg.t option -> module_like
val ident : path -> module_like
val str : m2l -> module_like
val ext : Transforms.param -> Uloc.t -> string -> unit
val m_with : Paths.Simple.set -> module_like -> module_like
val empty: module_like

val signature: module_like -> Module.signature option

(** With constraint *)
val with_module: delete:bool -> lhs:Paths.S.t -> rhs:module_like -> module_like -> module_like
val with_module_type: delete:bool -> lhs:Paths.S.t -> rhs:module_like -> module_like -> module_like


(** M2l *)
val m2l_add : state_diff -> m2l -> m2l
val m2l_init : m2l
val final: m2l -> Module.Sig.t

(** Module rec *)
val bind_rec_add : Name.t option -> module_like -> state_diff -> state_diff
val bind_rec_init : state_diff

(** Expr *)
val included : Transforms.param -> Uloc.t
  -> Id.seed -> Module.level -> module_like -> state_diff
val bind : Name.t option -> module_like -> state_diff
val bind_sig : Name.t option -> module_like -> state_diff
val opened : Transforms.param -> loc:Uloc.t -> module_like -> state_diff
val empty_diff: state_diff

module type state = sig
  type state
  type env
  val resolve :
  Transforms.param -> state -> path_in_context -> (query, unit) result
  val merge : state -> state_diff -> state
  val bind_arg : state -> module_like Module.Arg.t -> state
  val is_alias : Transforms.param -> state -> Paths.Simple.t -> bool
  val restart : state -> state_diff -> state
  val bind_alias : state -> Name.t option -> Paths.Simple.t -> state_diff
  val diff : state -> state_diff
  val open_path :
    param:Transforms.param -> loc:Uloc.t -> state -> path -> state
  val from_env: ?diff:state_diff -> env -> state
  val rec_approximate: state -> _ M2l.bind list -> state

  val rec_patch: Summary.t -> state_diff -> state_diff

  (** to be deleted ?*)
  val peek: state_diff -> Summary.t
end

module State(Env:Stage.envt): state with type env = Env.t
