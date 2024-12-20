open! Core

module Site_config : sig
  type t =
    { title : string
    ; base_url : string
    ; domain_name : string
    ; description : string
    ; author : string
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

  val create : Post.t -> base_url:string -> t
end

val create_rss_feed : Site_config.t -> Post.t list -> string
val create_atom_feed : Site_config.t -> Post.t list -> string
