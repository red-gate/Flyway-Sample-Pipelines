# How to wire pipeline variables to environments
## Changes to vars.yml
Remove the username and password variables from the Flyway command. These will be brought in later with the environments
## Changes to yaml files (deploy.yml, build.yml)
Map pipeline variables to env variables in each flyway script step
![image](https://github.com/kathikelRG/Flyway-Sample-Pipelines/assets/148022047/f36e5012-bd06-46ad-9dcc-64f92e110a7c)

Remove Url, check.buildUrl, check.user, check.password from flyway commands. Replace with environment and check.buildEnvironment
![image](https://github.com/kathikelRG/Flyway-Sample-Pipelines/assets/148022047/d8d812ad-6b87-4e74-941e-7d69c8208f5b)

## Changes to flyway.toml
Add an environment section for each stage. Map env variables in the section. Important! Envrionment section name is case sensitive when adding to command.
![image](https://github.com/kathikelRG/Flyway-Sample-Pipelines/assets/148022047/29d694e1-15b5-4e2d-b195-7939b3045701)

Note that the environments with variables cannot be opened in Flyway Desktop. Flyway Desktop will work if opening a target on the Migrations tab with hard-coded values but not with the variables. 
![image](https://github.com/kathikelRG/Flyway-Sample-Pipelines/assets/148022047/c995cf32-b5c9-4d93-ae8e-c15605d39c3e)

