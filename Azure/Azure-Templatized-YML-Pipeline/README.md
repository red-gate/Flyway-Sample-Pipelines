CLI versions can be downloaded here: https://download.red-gate.com/maven/release/com/redgate/flyway/flyway-commandline

Instructions on usage here: https://www.red-gate.com/hub/university/courses/flyway/flyway-desktop-enterprise-implementation/preparing-for-the-poc/proof-of-concept

10.20.1+ NOTES:

Updated flyway command to use PAT: https://documentation.red-gate.com/fd/flyway-licensing-263061944.html

To create a PAT go here: https://identityprovider.red-gate.com/personaltokens

Updated pipeline to read TOML correctly, simplifying project setup and deprecating the need for a specific cherryPick pipeline - use TOML. TODO: Video content on this workflow. 

For Oracle, these are scripts that can be used in discovery to determine if cross schema references exist and other triage prior to POC. They should only be used on non production environments by a DBA. 

https://github.com/Dbakevlar/RG_Oracle