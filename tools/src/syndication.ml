open! Core
open Yocaml_syndication

module Site_config = struct
  open Ppx_yojson_conv_lib.Yojson_conv

  type t =
    { title : string
    ; base_url : string
    ; description : string
    ; author : string
    ; uuid : string
    ; site_generator_version : string
    }
  [@@deriving yojson]

  let generator t =
    Generator.make
      ~uri:"https://github.com/mt-caret/blog-src"
      ~version:t.site_generator_version
      "blog-src"
  ;;
end

let yocaml_datetime_of_date (date : Date.t) =
  Yocaml.Datetime.make
    ~year:(Date.year date)
    ~month:(Date.month date |> Month.to_int)
    ~day:(Date.day date)
    ()
  |> Result.ok
  |> Option.value_exn ~message:"Invalid date"
  |> Datetime.make
;;

module Post = struct
  type t =
    { title : string
    ; creation_date : Date.t
    ; update_date : Date.t
    ; url : string
    ; content_html : string
    ; uuid : string
    }
  [@@deriving fields ~getters]

  let create
    ({ date; update_date; title; category = _; tags = _; uuid } : Metadata.t)
    ~slug
    ~base_url
    ~content_html
    =
    { title
    ; creation_date = date
    ; update_date = Option.value update_date ~default:date
    ; url = [%string "%{base_url}/%{slug}"]
    ; content_html
    ; uuid
    }
  ;;

  let to_rss_item { title; creation_date; update_date = _; url; content_html; uuid = _ } =
    Rss.item
      ~title
      ~pub_date:(yocaml_datetime_of_date creation_date)
      ~link:url
      ~description:content_html
      ()
  ;;

  let to_atom_entry { title; creation_date; update_date; url; content_html; uuid } =
    Atom.entry
      ~published:(yocaml_datetime_of_date creation_date)
      ~links:[ Atom.self url ]
      ~content:(Atom.content_html content_html)
      ~title:(Atom.text title)
      ~id:uuid
      ~updated:(yocaml_datetime_of_date update_date)
      ()
  ;;
end

let create_rss_feed
  ({ title; base_url; description; author = _; uuid = _; site_generator_version = _ } as
   config :
    Site_config.t)
  posts
  =
  Rss.feed
    ~generator:(Site_config.generator config)
    ~title
    ~link:base_url
    ~url:base_url
    ~description
    Post.to_rss_item
    posts
  |> Xml.to_string
;;

let create_atom_feed
  ({ title; base_url = _; description = _; author; uuid; site_generator_version = _ } as
   config :
    Site_config.t)
  posts
  =
  let most_recent_update_date =
    List.map posts ~f:Post.update_date
    |> List.max_elt ~compare:Date.compare
    |> Option.value ~default:Date.unix_epoch
  in
  Atom.feed
    ~generator:(Some (Site_config.generator config))
    ~updated:(Atom.updated_given (yocaml_datetime_of_date most_recent_update_date))
    ~title:(Atom.text title)
    ~authors:[ Person.make author ]
    ~id:uuid
    Post.to_atom_entry
    posts
  |> Xml.to_string
;;

let%test_module _ =
  (module struct
    let config : Site_config.t =
      { title = "Test"
      ; base_url = "https://test.com"
      ; description = "Test"
      ; author = "author"
      ; uuid = "test"
      ; site_generator_version = "1.0.0"
      }
    ;;

    let posts : Post.t list =
      [ { title = "Test post"
        ; creation_date = Date.unix_epoch
        ; update_date = Date.unix_epoch
        ; url = "https://test.com/test-post"
        ; content_html = "<article>Test post</article>"
        ; uuid = "test-post"
        }
      ]
    ;;

    let%expect_test "Site_config.yojson" =
      [%yojson_of: Site_config.t] config |> Yojson.Safe.pretty_to_string |> print_endline;
      [%expect
        {|
        {
          "title": "Test",
          "base_url": "https://test.com",
          "description": "Test",
          "author": "author",
          "uuid": "test",
          "site_generator_version": "1.0.0"
        }
        |}]
    ;;

    let%expect_test "create_rss_feed" =
      create_rss_feed config posts |> print_endline;
      [%expect
        {|
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
          <channel>
            <title>Test</title>
            <link>https://test.com</link>
            <description><![CDATA[Test]]></description>
            <atom:link href="https://test.com" rel="self" type="application/rss+xml"/>
            <docs>https://www.rssboard.org/rss-specification</docs>
            <generator>blog-src</generator>
            <item>
              <title>Test post</title>
              <link>https://test.com/test-post</link>
              <description><![CDATA[<article>Test post</article>]]></description>
              <pubDate>Thu, 01 Jan 1970 00:00:00 GMT</pubDate>
            </item>
          </channel>
        </rss>
        |}]
    ;;

    let%expect_test "create_atom_feed" =
      create_atom_feed config posts |> print_endline;
      [%expect
        {|
        <?xml version="1.0" encoding="utf-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <id>test</id>
          <title type="text">Test</title>
          <generator uri="https://github.com/mt-caret/blog-src" version="1.0.0">blog-src</generator>
          <updated>1970-01-01T00:00:00Z</updated>
          <author>
            <name>author</name>
          </author>
          <entry>
            <id>test-post</id>
            <title type="text">Test post</title>
            <updated>1970-01-01T00:00:00Z</updated>
            <published>1970-01-01T00:00:00Z</published>
            <content type="html">&lt;article&gt;Test post&lt;/article&gt;</content>
            <link href="https://test.com/test-post" rel="self"/>
          </entry>
        </feed>
        |}]
    ;;
  end)
;;
