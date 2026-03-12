# Video 01: Project Initialization with `flyway init`

## Overview
Learn how to initialize a new Flyway project from scratch using the `flyway init` command.

## Duration
5-8 minutes

## Learning Objectives
- Understand what `flyway init` does
- Create a new Flyway project
- Explore the generated project structure
- Understand the flyway.toml configuration file

---

## Script

### Intro (30 seconds)
"Welcome to the Flyway CLI video series! In this first video, we'll learn how to initialize a new Flyway project using the `flyway init` command. This is the starting point for any Flyway-based database versioning project."

### Part 1: Understanding `flyway init` (1 minute)

**Talking Points:**
- `flyway init` creates a new Flyway project structure
- It generates configuration files, folders for migrations, and a schema model
- Think of it like `git init` but for database versioning

**Command to show help:**
```powershell
flyway help init
```

**Expected output discussion:**
- `init.projectName` - Required: Name your project
- `init.databaseType` - Required: Specify your database (sqlserver, postgresql, mysql, oracle, etc.)
- `init.fileName` - Optional: Custom config filename (defaults to flyway.toml)
- `init.from` / `init.fromType` - For migrating from existing projects

### Part 2: Creating a New Project (2 minutes)

**Talking Points:**
- We'll create a project directory first
- Then run `flyway init` with our project settings

**Commands:**
```powershell
# Create and navigate to project directory
mkdir FlywayDemo
cd FlywayDemo

# Initialize the Flyway project
flyway init "-init.projectName=FlywayDemo" "-init.databaseType=sqlserver"
```

**Expected Output:**
```
Successfully initialized project at path: C:\...\FlywayDemo\flyway.toml
```

### Part 3: Exploring the Project Structure (2 minutes)

**Command to view structure:**
```powershell
Get-ChildItem -Recurse | Select-Object FullName
```

**Talking Points - Explain each file/folder:**

| File/Folder | Purpose |
|-------------|---------|
| `flyway.toml` | Main configuration file - contains project settings |
| `flyway.user.toml` | User-specific settings (gitignored) - for local credentials |
| `migrations/` | Where versioned migration scripts live |
| `schema-model/` | File-based representation of your database schema |
| `Filter.scpf` | SQL Compare filter file - controls what objects to include |
| `.gitignore` | Prevents sensitive files from being committed |

### Part 4: Understanding flyway.toml (2 minutes)

**Command:**
```powershell
Get-Content flyway.toml
```

**Key sections to highlight:**
```toml
# Project identity
databaseType = "sqlserver"
name = "FlywayDemo"

# Core Flyway settings
[flyway]
locations = [ "filesystem:migrations" ]
mixed = true
outOfOrder = true
schemaModelLocation = "schema-model"

# Desktop integration settings
[flywayDesktop]
developmentEnvironment = "development"
shadowEnvironment = "shadow"
```

**Explain:**
- `locations` - Where Flyway looks for migration scripts
- `mixed` - Allows versioned and repeatable migrations together
- `outOfOrder` - Allows migrations to run out of order (useful for teams)
- `schemaModelLocation` - Path to schema model folder

### Part 5: Adding Environment Configuration (1 minute)

**Talking Points:**
- By default, no database connections are configured
- You need to add environments for development, shadow, and deployment targets

**Example configuration to add:**
```toml
[environments.development]
url = "jdbc:sqlserver://localhost;databaseName=MyDevDB;encrypt=true;integratedSecurity=true;trustServerCertificate=true"

[environments.shadow]
url = "jdbc:sqlserver://localhost;databaseName=MyShadowDB;encrypt=true;integratedSecurity=true;trustServerCertificate=true"
provisioner = "clean"
```

### Closing (30 seconds)
"You've now created your first Flyway project! The project structure is ready for you to start capturing your database schema and creating migrations. In the next video, we'll learn how to use `flyway diff` to compare your development database against the schema model."

---

## Commands Summary

```powershell
# View help
flyway help init

# Initialize a new project (SQL Server)
flyway init "-init.projectName=MyProject" "-init.databaseType=sqlserver"

# Initialize for PostgreSQL
flyway init "-init.projectName=MyProject" "-init.databaseType=postgresql"

# Initialize for MySQL
flyway init "-init.projectName=MyProject" "-init.databaseType=mysql"

# Initialize for Oracle
flyway init "-init.projectName=MyProject" "-init.databaseType=oracle"
```

## Common Issues & Tips

1. **Quote arguments with equals signs** - In PowerShell, wrap arguments containing `=` in quotes
2. **Run from empty directory** - Init works best in a new, empty folder
3. **Supported database types**: Run `flyway list-engines` to see all supported databases
