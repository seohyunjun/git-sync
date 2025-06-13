# Git Sync and Auto Redeploy

This setup uses Docker Compose to synchronize a Git repository and automatically rebuild and redeploy services when changes are detected in the repository.

## `docker-compose.yaml`

The main `docker-compose.yaml` file defines two services: `git-sync` and `watcher`.

### `git-sync` Service

*   **Purpose**: This service is responsible for keeping a local copy of a remote Git repository synchronized.
*   **Image**: Uses `registry.k8s.io/git-sync/git-sync:v4.1.0`.
*   **Core Functionality**: It periodically fetches changes from the specified remote repository.
*   **Configuration**: Key configurations are managed through environment variables, typically defined in a `.env` file:
    *   `GIT_SYNC_REPO`: The URL of the remote Git repository to sync.
    *   `GIT_SYNC_BRANCH`: The specific branch to sync.
    *   `GIT_SYNC_ROOT`: The parent directory within the container where the repository will be cloned (e.g., `/git`). The actual repository will be cloned into a subdirectory named after the repository itself (e.g., `/git/my-repo`).
    *   `GIT_SYNC_WAIT`: The interval in seconds at which to check for repository changes.
    *   `DEST_DIR`: The host directory that is mounted into the container at `GIT_SYNC_ROOT`. This is where the synced repository will reside on the host machine.
*   **SSH Access**: For private repositories, the service is configured to use SSH keys:
    *   `~/.ssh/git-sync`: This directory (on the host) should contain the SSH private key and is mounted to `/etc/git-secret/ssh` in the container.
    *   `~/.ssh/known_hosts`: This file (on the host) is mounted to `/etc/git-secret/known_hosts` in the container to verify host authenticity.
*   **Command**: Executes the `/entrypoint.sh` script to manage the sync process and subsequent actions.

### `watcher` Service

*   **Purpose**: This service appears to be designed to monitor a directory (presumably the synced repository or a part of it) and execute a build script when changes occur.
*   **Image**: Uses a basic `alpine` image.
*   **Volumes**:
    *   `UPDATE_REPO_DIR` (environment variable): This host directory is mounted to `/repo` inside the container.
*   **Entrypoint**: Executes `/repo/build.sh`. This implies that the directory specified by `UPDATE_REPO_DIR` is expected to contain a `build.sh` script.
*   **Note**: The `watcher` service operates in parallel to the auto-redeploy mechanism handled by the `entrypoint.sh` script within the `git-sync` service. It seems to provide a separate, more generic file watching and script execution capability.

## `entrypoint.sh`

This script is the command executed by the `git-sync` service and orchestrates the primary workflow of this setup.

*   **Initialization**:
    *   Determines the local directory (`REPO_DIR`) where the target repository will be synced (e.g., `${GIT_SYNC_ROOT}/${GIT_SYNC_REPO##*/}`).
    *   Starts the `git-sync` utility in the background. This utility handles the actual cloning/pulling of the remote repository to `REPO_DIR`.

*   **Change Monitoring Loop**:
    *   The script enters an infinite loop to continuously monitor for changes in the synced repository.
    *   It sleeps for the duration specified by `GIT_SYNC_WAIT` between checks.
    *   In each iteration, it retrieves the current `HEAD` commit hash of the local repository.

*   **Action on Change Detection**:
    *   If the current commit hash differs from the previously recorded hash, it signifies that new changes have been pulled.
    *   **Logging**: It logs the new commit hash.
    *   **Build**: It executes `docker compose -f "$REPO_DIR/docker-compose.yml" build`. This means it expects the **synced repository itself** to contain its own `docker-compose.yml` file, which defines the application's services and how to build them.
    *   **Redeploy**: It then runs `docker compose -f "$REPO_DIR/docker-compose.yml" up -d --remove-orphans` to restart the services defined in the synced repository's `docker-compose.yml` with the newly built images.

## Prerequisites

Before running this setup, ensure the following prerequisites are met:

1.  **Docker and Docker Compose**: Must be installed on your system.
2.  **`.env` File**: Create a `.env` file in the same directory as the main `docker-compose.yaml` file. This file should define the following environment variables:
    *   `GIT_SYNC_REPO`: The URL of the remote Git repository (e.g., `git@github.com:user/my-project.git`).
    *   `GIT_SYNC_BRANCH`: The branch to sync (e.g., `main` or `develop`).
    *   `GIT_SYNC_ROOT`: The parent directory *inside the container* for syncing. A common value is `/git`.
    *   `GIT_SYNC_WAIT`: The sync interval in seconds (e.g., `60` for 1 minute).
    *   `DEST_DIR`: The absolute or relative path on the **host machine** where the repository will be cloned and monitored (e.g., `./synced-repo`). This directory will be mounted into the `git-sync` container at `GIT_SYNC_ROOT`.
    *   `UPDATE_REPO_DIR`: The absolute or relative path on the **host machine** that the `watcher` service will monitor. This could be the same as `DEST_DIR` or a subdirectory within it, depending on your needs (e.g., `./synced-repo` or `./synced-repo/frontend`).

3.  **SSH Keys (for private repositories)**:
    *   If `GIT_SYNC_REPO` is a private repository requiring SSH authentication:
        *   Ensure you have an SSH key pair.
        *   Place the private key in `~/.ssh/git-sync` (e.g., `~/.ssh/git-sync/id_rsa`).
        *   Ensure the corresponding public key is added to your Git provider (e.g., GitHub, GitLab).
        *   Add the repository's host key to your `~/.ssh/known_hosts` file. You can often do this by attempting an initial manual SSH connection to the Git host (e.g., `ssh -T git@github.com`).

4.  **Synced Repository Requirements**:
    *   The repository specified by `GIT_SYNC_REPO` **must** contain its own `docker-compose.yml` file at its root. This file defines the application services to be built and run.
    *   If you intend to use the `watcher` service, the directory specified by `UPDATE_REPO_DIR` (which is typically the synced repository or a part of it) **must** contain a `build.sh` script.

## Usage

1.  **Clone this Repository (Optional)**: If this `docker-compose.yaml` and `entrypoint.sh` are part of a larger setup repository, clone that first. Otherwise, ensure `docker-compose.yaml` and `entrypoint.sh` are in your current directory.

2.  **Set up SSH Keys**:
    *   If you are syncing a private repository, create the directory `~/.ssh/git-sync`.
    *   Place your SSH private key (e.g., `id_rsa`) that has access to the target repository into `~/.ssh/git-sync/`.
    *   Ensure your `~/.ssh/known_hosts` file is populated with the host key of your Git server (e.g., `github.com`).

3.  **Create and Configure `.env` File**:
    *   Create a file named `.env` in the same directory as this `docker-compose.yaml`.
    *   Add the required environment variables as described in the "Prerequisites" section. Example:
        ```env
        GIT_SYNC_REPO=git@github.com:your-username/your-app-repo.git
        GIT_SYNC_BRANCH=main
        GIT_SYNC_ROOT=/git
        GIT_SYNC_WAIT=30
        DEST_DIR=./app-repo-checkout
        UPDATE_REPO_DIR=./app-repo-checkout
        ```

4.  **Ensure Target Repository Structure**:
    *   Verify that the remote repository (`GIT_SYNC_REPO`) contains a `docker-compose.yml` at its root. This file will define the services of your application.
    *   If using the `watcher` service, ensure the target directory (`UPDATE_REPO_DIR`) contains a `build.sh` script.

5.  **Start the Services**:
    *   Open a terminal in the directory containing the main `docker-compose.yaml` (and your `.env` file).
    *   Run the command:
        ```bash
        docker-compose up -d
        ```
    *   This will start the `git-sync` service (which in turn runs the `entrypoint.sh` script) and the `watcher` service in detached mode.

6.  **Monitoring**:
    *   You can view the logs of the `git-sync` service to see its activity, including when it detects changes and triggers builds:
        ```bash
        docker-compose logs -f git-sync
        ```
    *   Similarly, for the `watcher` service:
        ```bash
        docker-compose logs -f watcher
        ```

## How it Works (Workflow)

The system operates as follows:

1.  **Initialization**:
    *   When you run `docker-compose up -d`, the `git-sync` service and the `watcher` service are started.
    *   The `git-sync` service executes the `entrypoint.sh` script.

2.  **Initial Git Sync**:
    *   The `entrypoint.sh` script starts the `git-sync` process in the background.
    *   `git-sync` clones the remote repository (specified by `GIT_SYNC_REPO` and `GIT_SYNC_BRANCH`) into the directory specified by `DEST_DIR` (via the `GIT_SYNC_ROOT` mount).

3.  **Continuous Monitoring**:
    *   The `entrypoint.sh` script enters a loop, periodically checking the local synced repository for new commits by comparing the current `HEAD` hash with the last known hash. The check interval is defined by `GIT_SYNC_WAIT`.

4.  **Change Detection and Redeployment**:
    *   If a new commit is detected in the synced repository:
        *   The script logs the change.
        *   It then uses the `docker-compose.yml` file **found within the root of the synced repository** to build new Docker images for the application (`docker compose -f path/to/synced/repo/docker-compose.yml build`).
        *   After a successful build, it restarts the application's services using the same `docker-compose.yml` file from the synced repository (`docker compose -f path/to/synced/repo/docker-compose.yml up -d --remove-orphans`).

5.  **`watcher` Service (Parallel Process)**:
    *   Independently, the `watcher` service monitors the directory specified by `UPDATE_REPO_DIR`.
    *   If changes occur in this directory (and a `build.sh` script exists there), the `watcher` service will execute `/repo/build.sh`. This can be used for auxiliary build tasks, frontend asset compilation, or other processes that need to be triggered by file changes in the repository, potentially in parallel with the main application's redeployment.

This creates a continuous integration and deployment (CI/CD) like pipeline where code pushed to the specified Git repository branch is automatically pulled, built, and redeployed.
