use std::{collections::HashMap, env, path::PathBuf};

use codeowners::runner::{self, RunConfig};
use magnus::{Error, Ruby, Value, function, prelude::*};
use serde::{Deserialize, Serialize};
use serde_magnus::serialize;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Team {
    pub team_name: String,
    pub team_config_yml: String,
    pub reasons: Vec<String>,
}

fn for_team(ruby: &Ruby, team_name: String) -> Result<Value, Error> {
    let run_config = build_run_config();
    let team = runner::for_team(&run_config, &team_name);
    validate_result(ruby, &team)
}

fn teams_for_files(ruby: &Ruby, file_paths: Vec<String>) -> Result<Value, Error> {
    let run_config = build_run_config();
    let path_teams = runner::teams_for_files_from_codeowners(&run_config, &file_paths);
    match path_teams {
        Ok(path_teams) => {
            let mut teams_map: HashMap<String, Option<Team>> = HashMap::new();
            for (path, team) in path_teams {
                if let Some(found_team) = team {
                    teams_map.insert(path, Some(Team {
                        team_name: found_team.name.to_string(),
                        team_config_yml: found_team.name.to_string(),
                        reasons: vec![],
                    }));
                } else {
                    teams_map.insert(path, None);
                }
            }
            let serialized: Value = serialize(ruby, &teams_map)?;
            Ok(serialized)
        }
        Err(e) => Err(Error::new(ruby.exception_runtime_error(), e.to_string())),
    }
}

fn for_file(ruby: &Ruby, file_path: String) -> Result<Option<Value>, Error> {
    let run_config = build_run_config();

    match runner::file_owner_for_file(&run_config, &file_path) {
        Ok(owner) => {
            if let Some(owner) = owner {
            let team = Team {
                team_name: owner.team.name,
                team_config_yml: owner.team_config_file_path.to_string(),
                reasons: owner
                .sources
                .iter()
                .map(|source| source.to_string())
                .collect(),
            };
            let serialized: Value = serialize(ruby, &team)?;
            Ok(Some(serialized))
            } else {
                Ok(None)
            }
        }
        Err(e) => Err(Error::new(
            ruby.exception_runtime_error(),
            e.to_string(),
        )),
    }
}

fn version() -> String {
   runner::version()
}

fn validate(ruby: &Ruby, files: Option<Vec<String>>) -> Result<Value, Error> {
    let run_config = build_run_config();
    let files_vec = files.unwrap_or_default();
    let run_result = runner::validate(&run_config, files_vec);
    validate_result(ruby, &run_result)
}

fn generate_and_validate(ruby: &Ruby, files: Option<Vec<String>>, skip_stage: bool) -> Result<Value, Error> {
    let run_config = build_run_config();
    let files_vec = files.unwrap_or_default();
    let run_result = runner::generate_and_validate(&run_config, files_vec, skip_stage);
    validate_result(ruby, &run_result)
}

fn validate_result(ruby: &Ruby, run_result: &runner::RunResult) -> Result<Value, Error> {
    if !run_result.validation_errors.is_empty() {
        Err(Error::new(
            ruby.exception_runtime_error(),
            run_result.validation_errors.join("\n"),
        ))
    } else if !run_result.io_errors.is_empty() {
        Err(Error::new(
            ruby.exception_runtime_error(),
            run_result.io_errors.join("\n"),
        ))
    } else {
        let serialized: Value = serialize(ruby, &run_result.info_messages)?;
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
    module.define_singleton_method("generate_and_validate", function!(generate_and_validate, 2))?;
    module.define_singleton_method("validate", function!(validate, 1))?;
    module.define_singleton_method("for_team", function!(for_team, 1))?;
    module.define_singleton_method("version", function!(version, 0))?;
    module.define_singleton_method("teams_for_files", function!(teams_for_files, 1))?;

    Ok(())
}
