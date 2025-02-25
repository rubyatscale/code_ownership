use std::path::PathBuf;

use codeowners::runner::{self, RunConfig};
use magnus::{function, prelude::*, Error, Ruby, Value};
use serde::{Deserialize, Serialize};
use serde_magnus::serialize;

fn for_team(team: String) -> Result<Value, Error> {
    let result = CodeOwnersResult {
        output: vec!["success dog".to_string(), team],
        success: true,
    };
    let serialized: Value = serialize(&result)?;
    Ok(serialized)
}

fn generate_and_validate(files: Vec<String>) -> Result<Value, Error> {
    let run_config = build_run_config();
    let result = runner::generate_and_validate(&run_config, files);
    let serialized: Value = serialize(&result)?;
    Ok(serialized)
}

fn validate(files: Vec<String>) -> Result<Value, Error> {
    let run_config = build_run_config();
    let result = runner::validate(&run_config, files);
    let serialized: Value = serialize(&result)?;
    Ok(serialized)
}

fn build_run_config() -> RunConfig {
    RunConfig {
        project_root: PathBuf::from("."),
        codeowners_file_path: PathBuf::from("./github/CODEOWNERS"),
        config_path: PathBuf::from("./config/code_ownership.yml"),
        no_cache: false,
    }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CodeOwnersResult {
    pub output: Vec<String>,
    pub success: bool,
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("RustCodeOwners")?;
    module.define_singleton_method("for_team", function!(for_team, 1))?;
    module.define_singleton_method("generate_and_validate", function!(generate_and_validate, 1))?;
    module.define_singleton_method("validate", function!(validate, 1))?;

    Ok(())
}
