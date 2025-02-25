use std::{env, path::PathBuf};

use codeowners::runner::{self, RunConfig};
use magnus::{function, prelude::*, Error, Ruby, Value};
use serde::{Deserialize, Serialize};
use serde_magnus::serialize;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Team {
    pub team_name: String,
    pub team_config_yml: String,
}

fn for_file(file_path: String) -> Result<Option<Value>, Error> {
    let run_config = build_run_config();
    let result = runner::team_for_file_from_codeowners(&run_config, &file_path);

    match result {
        Ok(Some(team_rs)) => {
            let team =Team {
                team_name: team_rs.name,
                team_config_yml: team_rs.path.to_string_lossy().to_string(),
            };
            let serialized: Value = serialize(&team)?;
            Ok(Some(serialized))
        }
        Ok(None) => {
            Ok(None)
        }
        Err(e) => {
            Err(Error::new(magnus::exception::runtime_error(), e.to_string()))
        }
    }
}

fn build_run_config() -> RunConfig {
    let project_root = match env::current_dir() {
        Ok(path) => path,
        _ => PathBuf::from("."),
    };
    let codeowners_file_path = project_root.join(".github/CODEOWNERS");
    let config_path = project_root.join("config/code_ownership.yml");

    RunConfig {
        project_root,
        codeowners_file_path,
        config_path,
        no_cache: false,
    }
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("RustCodeOwners")?;
    module.define_singleton_method("for_file", function!(for_file, 1))?;

    Ok(())
}
