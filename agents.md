# Automation Agents in `mystarters`

The scripts within this repository act as automation agents, designed to streamline and standardize various development environment setup and project scaffolding tasks. They encapsulate best practices and common configurations, allowing for rapid deployment and consistent environments.

## How These Agents Work

Each script or set of scripts under `scripts/` can be thought of as a specialized agent. They are primarily shell scripts (`.sh`) that perform a series of commands to achieve a specific automation goal.

## Agent Categories

### 1. Infrastructure-as-Code Agents
These agents help in quickly setting up projects for infrastructure management.

*   **Ansible Agents (`scripts/ansible/`)**:
    *   `ansible-structure.sh`: A project scaffolding agent that creates a complete Ansible project structure, including inventory, playbooks, roles directories, and common configuration files. This agent ensures a standardized starting point for new Ansible initiatives.
    *   `ansible-roles-structure.sh`: An role scaffolding agent that generates the directory structure for a new Ansible role, promoting modularity and reusability within larger Ansible projects.

*   **Terraform Agents (`scripts/terraform/`)**:
    *   `terraform-skeleton-start.sh`: (Details to be confirmed, but likely) A project scaffolding agent for Terraform, setting up a basic directory structure and essential files for a new Terraform configuration.

### 2. Personal Environment Agents
These agents automate the setup and configuration of your personal development environment across different machines.

*   **Dotfiles Agents (`scripts/dotfiles/`)**:
    *   `clone-dotfiles.sh`: An agent responsible for cloning your personal dotfiles repository, making your custom configurations available on a new system.
    *   `dotfiles-configure-interactive.sh`: A comprehensive setup agent that not only fetches dotfiles but also orchestrates the installation of key tools like `chezmoi` (for managing dotfiles) and `lastpass-cli` (for secure credential management). It also handles SSH key retrieval and application of configurations.

### 3. System Setup Agents
These agents are specialized for performing initial system-level configurations for various operating systems.

*   **OS-Specific Agents (`scripts/system/`)**:
    *   `setup-linux.sh`: An agent for Linux systems, automating common post-installation tasks, package installations, and system configurations.
    *   `setup-macos.sh`: An agent for macOS, handling brew installations, system preferences, and other macOS-specific setups.
    *   `setup-wsl.sh`: An agent specifically designed for Windows Subsystem for Linux (WSL) environments, optimizing its configuration and installing necessary tools for a smooth development experience.

### 4. General Utility Agents
These agents provide generalized automation for common development tasks.

*   **Project Utility Agents (`scripts/utils/`)**:
    *   `create-project-structure.sh`: A versatile agent for generating generic project directory structures, based on templates or user input, ensuring consistency across different types of projects.
    *   `install-tools.sh`: An agent that automates the installation of a predefined set of development tools and dependencies, reducing manual setup time for new environments.

## Customization and Extension

The modular nature of these shell scripts allows for easy customization and extension. Users can modify existing agents to suit their specific needs, add new agents for recurring tasks, or combine agents to create more complex automated workflows.

## Contributing

Contributions of new automation agents or improvements to existing ones are welcome to expand the capabilities and usefulness of this `mystarters` repository.