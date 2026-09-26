/// Must match pixer_abi_version in the Rust engine.
const pixerAbiVersion = 1;

void checkPixerAbi(int actual) {
  if (actual != pixerAbiVersion) {
    throw StateError(
      'Pixer ABI mismatch: expected $pixerAbiVersion, got $actual. '
      'Rebuild or download the binary matching this Pixer package.',
    );
  }
}
