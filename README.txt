Overview of WSL and Docker Deployment
======================================

This package provides a fully‐automated, multi‑phase setup for deploying an
isolated Windows Subsystem for Linux (WSL) environment and a Docker runtime
across multiple drives.  The goal is to keep the operating system and user
profile on the `C:` drive untouched while utilising the high‑capacity `K:` drive
for long‑term storage, the fast `D:` drive for active workloads, and the
RAM‑speed `P:` drive for hot production workloads.  The scripts in this
package can be executed sequentially or starting from any phase, allowing
flexibility if you need to re‑run a particular step.

Targeted Outcome
----------------

* **Data Isolation:**  No WSL or Docker data will reside on the `C:` drive.
* **Structured Storage:**  Active WSL distributions and Docker images run
  exclusively from the `D:` drive.  Baseline distributions and master copies
  of AI models live on `K:`.  The `P:` drive is reserved for promoted
  workloads that require maximum performance.
* **Self‑contained Scripts:**  Each phase has its own PowerShell script to
  perform the necessary work and a corresponding validation script to verify
  success.  A single launcher (`start_setup.ps1`) presents an easy menu for
  executing one or more phases.

Phases
------

1. **Phase 1 – Directory Preparation**
   * Creates the required folder structure on `D:`, `K:` and `P:`.
   * Validates that directories exist after creation.

2. **Phase 2 – Baseline Import**
   * Downloads a clean Ubuntu WSL root filesystem (Ubuntu 24.04) to
     K:\\Baselines\\WSL.  If the file already exists it is reused.
   * Imports the distribution into D:\\WSL\\Ubuntu-Dev and ensures WSL
     defaults to version 2.
   * Validates that the distribution is present and its .vhdx file lives
     entirely on the `D:` drive.

3. **Phase 3 – WSL Configuration and Docker Installation**
   * Configures the imported WSL distribution to enable systemd via
     /etc/wsl.conf so services (like Docker) can run normally.
   * Installs the Docker Engine inside the Ubuntu distribution using
     the official Docker APT repository.
   * Validates that systemd is enabled and that Docker is running and
     responding to docker info.

4. **Phase 4 – Model Path Setup**
   * Creates a junction (D:\\ModelsCurrent) pointing to
     K:\\Models.  This junction serves as a stable entry point for
     containers and applications; its target can later be repointed to
     `P:` when you promote a model to run at full speed.
   * Validates that the junction exists and points at the correct target.

How to Use
----------

* Extract the zip archive to a convenient location.
* Open an elevated PowerShell window and run start_setup.ps1.  You
  will be prompted for a phase number or all to run all phases.
* Upon completion of each phase the script will automatically run the
  associated validation script and output a status message.  Validation
  reports are stored in the reports folder.

If you encounter errors during validation, share the contents of the
corresponding report file with your assistant for diagnosis.
