## ADDED Requirements

### Requirement: Install age when missing
The script MUST detect whether `age` is installed and MUST install it when it is not available.

#### Scenario: age is already installed
- **WHEN** the script starts and `age` is available on PATH
- **THEN** the script MUST skip installation and continue

#### Scenario: age is missing on macOS
- **WHEN** the script starts on macOS and `age` is not available on PATH
- **THEN** the script MUST install `age` with Homebrew

#### Scenario: age is missing on Debian-based Linux
- **WHEN** the script starts on Debian-based Linux and `age` is not available on PATH
- **THEN** the script MUST install `age` with `apt`

### Requirement: Reuse a purpose-specific key
The script MUST prompt for a purpose and MUST reuse the existing key file for that purpose if it already exists.

#### Scenario: existing purpose key is present
- **WHEN** the user enters a purpose that maps to an existing key file
- **THEN** the script MUST reuse that key file instead of generating a new one

#### Scenario: purpose key does not exist
- **WHEN** the user enters a purpose that does not yet have a key file
- **THEN** the script MUST generate a new key file for that purpose

### Requirement: Store keys under ~/.config/age
The script MUST store generated age private keys under `~/.config/age` and MUST ensure the directory exists before writing a key.

#### Scenario: key directory is missing
- **WHEN** the script needs to create or reuse a key and `~/.config/age` does not exist
- **THEN** the script MUST create the directory before accessing the key file

#### Scenario: key file is created
- **WHEN** the script generates a new key file
- **THEN** the private key MUST be written inside `~/.config/age`

### Requirement: Print key path and public key
The script MUST output the resolved private key path and the corresponding public key after setup completes.

#### Scenario: setup completes successfully
- **WHEN** the script finishes creating or reusing a key
- **THEN** it MUST print the private key path and the public key

### Requirement: Show encrypt and decrypt examples
The script MUST print example commands that show how to encrypt a demo file and decrypt it with the generated key.

#### Scenario: setup completes successfully
- **WHEN** the script finishes creating or reusing a key
- **THEN** it MUST print example `age` commands for encrypting and decrypting a demo file
