#![cfg_attr(target_arch = "arm", no_std)]
#![cfg_attr(target_arch = "arm", no_main)]

#[cfg(target_arch = "arm")]
use embedded_test::{DroneBackend, HwBackend};

#[cfg(not(target_arch = "arm"))]
use linux_test::{DroneBackend, SimBackend};

#[cfg_attr(target_arch = "arm", cortex_m_rt::entry)]
fn main() -> ! {
    #[cfg(target_arch = "arm")]
    let mut backend = HwBackend::initialize();

    #[cfg(not(target_arch = "arm"))]
    let mut backend = SimBackend::initialize();

    loop {
        backend.execute_action().expect("Failed to execute action");
    }
}
