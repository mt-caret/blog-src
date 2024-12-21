  $ ./tools.exe help -expand-dots -flags -recursive
  Tools for generating blog
  
    tools.exe SUBCOMMAND
  
  === subcommands and flags ===
  
    build-index                . Build index.html
    build-index -git-revision STRING
                               . Git revision
    build-index -template PATH . Path to template file
    build-index [-category Generate]
                               . index for category
    build-index [-root-dir DIR]
                               . root dir relative to output dir
    build-index [-tag Generate]
                               . index for tag
    build-post                 . Build a post
    build-post -git-revision STRING
                               . Git revision
    build-post -template PATH  . Path to template file
    print-dune-rules           . Print out dune rules
    print-dune-rules -git-revision-file PATH
                               . Path to git revision file
    print-dune-rules -template PATH
                               . Path to template file
    print-dune-rules [-kind Kind]
                               . of rule to print (can be: category, index, tag)
    syndication-feeds          . Generate syndication feeds
    syndication-feeds -site-config PATH
                               . Path to site config file
    version                    . print version information
    version [-build-info]      . print build info for this build
    version [-version]         . print the version of this build
    help                       . explain a given subcommand (perhaps recursively)
    help [-expand-dots]        . expand subcommands in recursive help
    help [-flags]              . show flags as well in recursive help
    help [-recursive]          . show subcommands of subcommands, etc.
  
