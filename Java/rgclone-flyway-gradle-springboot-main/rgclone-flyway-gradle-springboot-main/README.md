# Objective:

Create a build that does the following:

1. Create an ephemeral Oracle DB data-container with Redgate Clone. (This mocks a "production" database instance.)
2. Run Flyway migrate within a Java Spring Boot application against a database schema on the data container created in step 1. (To perform a mock test deployment.) 
3. Delete the data container upon completion.

This build could, in theory, be extended to include production migrations, if the test migrations are successful.

The aim in this case is to keep the code as simple as possible, and to keep as much of the complexity as possible in gradle. That way, anyone can take this gradle and run it wherever they like.

# How this works

There is a "./gradle" folder that contains all the build logic. The important file is "build.gradle". This contains the gradle code for performing various tasks:

- setupRgCloneCli
- createDataContainer
- getContainer

In addition, there is a coordinator task, which is called during the build:

- startCloneAndFlywayMigrate

There is a GitHub action saved at: ".github/workflows/build-gradle-project.yml"

This action calls gradle to perform the tasks above. It provides a few of parameters which are necessary to access and authenticate against a Redgate Clone server:

- RGCLONE_ENDPOINT (e.g. "https://myRgCloneCluster.com:8132")
- RGCLONE_TOKEN (See: https://documentation.red-gate.com/redgate-clone/administration/admin-console/configuration/authentication-settings#AuthenticationSettings-rgcloneAccessToken)
- FLYWAY_LICENCE (A Flyway Teams or Enterprise CLI licence. Starts FL0, followed by a 256 character string.)

The values for these parameters are saved as GitHub secrets.

# How to fork and run this yourself

Install your own Redgate Clone instance and create an empty Oracle data-image:
https://documentation.red-gate.com/redgate-clone/installation

Fork the repo, and create repository secrets to securely hold the URL and credentials for your own RgClone instance, as well as your Flyway CLI licence:

- RGCLONE_ENDPOINT (e.g. "https://myRgCloneCluster.com:8132")
- RGCLONE_TOKEN (See: https://documentation.red-gate.com/redgate-clone/administration/admin-console/configuration/authentication-settings#AuthenticationSettings-rgcloneAccessToken)
- FLYWAY_LICENCE (A Flyway Teams or Enterprise CLI licence. Starts FL0, followed by a 256 character string.)

Run the GitHub action.
