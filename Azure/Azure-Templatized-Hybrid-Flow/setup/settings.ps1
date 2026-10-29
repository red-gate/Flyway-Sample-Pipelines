# Settings for the setup scripts. Edit this file, then run the numbered scripts in order.
# Every name (project, repos, databases, variable groups, environments, pipelines) is built from
# Prefix, so changing it gives you a second, independent copy of the whole setup.

$Settings = @{
    Prefix          = 'northwind'

    # SQL Server that holds the databases. The same server written two ways:
    #   for sqlcmd:  'localhost', '.\SQLEXPRESS', 'sqlhost,1433'
    #   for JDBC:    'localhost:1433', 'sqlhost:1433'  (a named instance needs a fixed TCP port)
    SqlCmdServer    = 'localhost'
    JdbcServer      = 'localhost:1433'

    # Schema-only backup the shadow and check databases are restored from (Flyway's backup
    # provisioner). The path is read by SQL Server, so it must be on that server or on a file share
    # it can reach. Empty = <the server's default backup folder>\<Prefix>-baseline.bak. Step 1
    # creates it if it doesn't exist; step 2 writes its path and version into the pipelines.
    BaselineBackupPath = ''

    # Empty = Windows (integrated) authentication. The pipeline agent then has to run as a Windows
    # user that can reach the databases. Otherwise a SQL login that can create databases.
    SqlUser         = ''
    SqlPassword     = ''

    # Azure DevOps Server collection, or Azure DevOps Services organisation.
    #   Server:   'http://localhost/DefaultCollection'   (Pat empty = your Windows login)
    #   Services: 'https://dev.azure.com/<org>'          (Pat required, Full access is simplest)
    CollectionUrl   = 'http://localhost/DefaultCollection'
    Pat             = ''

    # Self-hosted agent. The pipelines run on this pool. On a server whose Default pool already has
    # other agents (they'd need Flyway too), use a new name: 2-setup-azure-devops.ps1 creates the pool.
    AgentPool       = 'Default'
    AgentDir        = 'C:\agent'
    # Only used if the server doesn't say which agent it hands out.
    AgentVersion    = '4.260.0'

    # Flyway Enterprise licence, used by the agent and by 1-create-databases.ps1: a file with
    #   token=<personal access token from https://identityprovider.red-gate.com>
    #   email=<the email address the token belongs to>
    # Keep it out of source control (.env is in the repo's .gitignore). Never run `flyway auth` on
    # the agent: the token is read from this file every time the agent starts.
    FlywayLicenceFile = "$PSScriptRoot\.env"
}
