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
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CodeOwnersResult {
    pub output: Vec<String>,
    pub success: bool,
}


#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("FastCodeowners")?;
    module.define_singleton_method("for_team", function!(for_team, 1))?;

    Ok(())
}
