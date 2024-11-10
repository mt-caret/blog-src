open! Core

module Site_config : sig
  type t =
    { title : string
    ; base_url : string
    ; description : string
    ; author : string
    ; uuid : string
    ; site_generator_version : string
    }
  [@@deriving yojson]
end

module Post : sig
  type t =
    { title : string
    ; creation_date : Date.t
    ; update_date : Date.t
    ; url : string
    ; content_html : string
    ; uuid : string
    }

  val create : Metadata.t -> slug:string -> base_url:string -> content_html:string -> t
end

val create_rss_feed : Site_config.t -> Post.t list -> string
val create_atom_feed : Site_config.t -> Post.t list -> string