//! Kernel-specific error types.

use openagent_types::error::OpenAgentError;
use thiserror::Error;

/// Kernel error type wrapping OpenAgentError with kernel-specific context.
#[derive(Error, Debug)]
pub enum KernelError {
    /// A wrapped OpenAgentError.
    #[error(transparent)]
    OpenAgent(#[from] OpenAgentError),

    /// The kernel failed to boot.
    #[error("Boot failed: {0}")]
    BootFailed(String),
}

/// Alias for kernel results.
pub type KernelResult<T> = Result<T, KernelError>;
