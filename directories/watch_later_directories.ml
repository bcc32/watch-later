open! Base

module D = Directories.Project_dirs (struct
    let qualifier = "com"
    let organization = "bcc32"
    let application = "watch-later"
  end)

let ( ^/ ) = Stdlib.Filename.concat
let default_db_path = Option.value_exn D.data_dir ^/ "watch-later.db"
let oauth_credentials_path = Option.value_exn D.config_dir ^/ "credentials"
