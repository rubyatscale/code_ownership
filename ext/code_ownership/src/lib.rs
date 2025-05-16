use std::{env, path::PathBuf};

use codeowners::runner::{self, RunConfig};
use magnus::{Error, Ruby, Value, function, prelude::*};
use serde::{Deserialize, Serialize};
use serde_magnus::serialize;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Team {
    pub team_name: String,
    pub team_config_yml: String,
}

fn for_file(file_path: String) -> Result<Option<Value>, Error> {
    let run_config = build_run_config();

    match runner::team_for_file_from_codeowners(&run_config, &file_path) {
        Ok(Some(team_rs)) => {
            let team = Team {
                team_name: team_rs.name,
                team_config_yml: team_rs.path.to_string_lossy().to_string(),
            };
            let serialized: Value = serialize(&team)?;
            Ok(Some(serialized))
        }
        Ok(None) => Ok(None),
        Err(e) => Err(Error::new(
            magnus::exception::runtime_error(),
            e.to_string(),
        )),
    }
}

fn validate() -> Result<Value, Error> {
    let run_config = build_run_config();
    let run_result = runner::validate(&run_config, vec![]);
    validate_result(&run_result)
    
}

fn generate_and_validate() -> Result<Value, Error> {
    let run_config = build_run_config();
    let run_result = runner::generate_and_validate(&run_config, vec![]);
    validate_result(&run_result)
}

fn validate_result(run_result: &runner::RunResult) -> Result<Value, Error> {
    if !run_result.validation_errors.is_empty() {
        Err(Error::new(
            magnus::exception::runtime_error(),
            run_result.validation_errors.join("\n"),
        ))
    } else if !run_result.io_errors.is_empty() {
        Err(Error::new(
            magnus::exception::runtime_error(),
            run_result.io_errors.join("\n"),
        ))
    } else {
        let serialized: Value = serialize(&run_result.info_messages)?;
        Ok(serialized)
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
    module.define_singleton_method("generate_and_validate", function!(generate_and_validate, 0))?;
    module.define_singleton_method("validate", function!(validate, 0))?;

    Ok(())
}
