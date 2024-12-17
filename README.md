The templatized azure devops pipeline (https://github.com/red-gate/Flyway-Sample-Pipelines/tree/main/Azure/Azure-Templatized-YML-Pipeline/flyway-10.20.1%2B) is our recommended approach. Instructions on usage here: https://www.red-gate.com/hub/university/courses/flyway/flyway-desktop-enterprise-implementation/preparing-for-the-poc/proof-of-concept

The folder structure has been re-organized to accommodate marking version numbers of the Flyway CLI parent folders to specific Flyway versions.

These pipelines are designed to support Enterprise and its functionality, though can easily be adjusted to support Teams. 

CLI versions can be downloaded here: https://download.red-gate.com/maven/release/com/redgate/flyway/flyway-commandline/

Useful Helper scripts from colleague Andrew Pierce can be found here: https://github.com/turimbar1/flyway-example-scripts/tree/main
    - Some shamelessly stolen

Changelog:

10.20.1+ (10/30/2024):

Updated flyway command to use PAT: https://documentation.red-gate.com/fd/flyway-licensing-263061944.html

Updated pipeline to read TOML correctly, simplifying project setup and deprecating the need for a specific cherryPick pipeline - use TOML. TODO: Video content on this workflow.

11+

New auth using tokens and PAT: https://documentation.red-gate.com/fd/flyway-licensing-263061944.html

username and password should now be included in JDBC

Updating templatized pipelines to use docker (commented out by default)