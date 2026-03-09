# Claude.ai Instructions for GitLab Flyway Pipeline Templates

## Project Purpose
This project provides **DRY (Don't Repeat Yourself)** GitLab CI/CD pipeline templates for Flyway database migrations that are:
- Easy to set up and use
- Support single or multiple (N) database targets
- Maintain all configuration in one central location
- Follow GitLab best practices for secrets management

## Core Principles

### 1. DRY Architecture
- **Single Source of Truth**: All Flyway command configurations are defined once in `.gitlab/ci/flyway.yml`
- **No Duplication**: Pipeline examples extend base templates, never duplicate command logic
- **Centralized Updates**: Changes to Flyway commands happen in ONE place only
- **Inheritance**: Use YAML anchors and GitLab `extends` keyword for reusability

### 2. Configuration Structure
```
.gitlab/ci/flyway.yml         # SINGLE SOURCE OF TRUTH - All Flyway job templates
.gitlab-ci-example-*.yml      # Example pipelines that extend base templates
.gitlab-ci.yml                # User's active pipeline (not in repo)
sql/                          # Migration scripts
CLAUDE_INSTRUCTIONS.md        # This file - Claude's behavioral guide
SETUP_GUIDE.md                # User setup instructions
README.md                     # Project overview
```

### 3. Secrets Management
All sensitive data MUST be stored as GitLab CI/CD variables, NEVER in code:

**Required Variables (stored in GitLab Settings → CI/CD → Variables):**
- `TARGET_DATABASE_JDBC` - JDBC connection string (e.g., `jdbc:postgresql://server:5432/dbname`)
- `TARGET_DATABASE_USER` - Database username
- `TARGET_DATABASE_PASSWORD` - Database password (masked, protected)

**For Multi-Database Deployments:**
Use numbered or named suffixes:
- `TARGET_DATABASE_JDBC_1`, `TARGET_DATABASE_JDBC_2`, ..., `TARGET_DATABASE_JDBC_N`
- `TARGET_DATABASE_USER_PROD`, `TARGET_DATABASE_USER_DEV`, etc.
- `TARGET_DATABASE_PASSWORD_DB1`, `TARGET_DATABASE_PASSWORD_DB2`, etc.

### 4. Multi-Database Support
The templates MUST support:
- **Single database**: Simple use case with one target
- **Multiple databases**: 2-10 databases with explicit job definitions
- **N databases**: Hundreds of databases using matrix/parallel strategies

**Implementation Approaches:**
1. **Explicit Jobs** (2-10 databases): Create individual jobs that extend base templates
2. **Matrix Strategy** (10-100 databases): Use GitLab parallel:matrix for dynamic jobs
3. **Dynamic Pipeline** (100+ databases): Generate child pipelines from configuration files

### 5. Template Maintenance Rules

#### When modifying flyway.yml:
- ✅ Add new reusable job templates as `.flyway_<command>`
- ✅ Update `.flyway_base` for changes affecting all jobs
- ✅ Keep all Flyway command-line arguments in the template
- ❌ NEVER add environment-specific values (URLs, credentials)
- ❌ NEVER hardcode database names or servers

#### When modifying example pipelines:
- ✅ Use `extends: .flyway_<command>` to inherit behavior
- ✅ Override only environment-specific variables
- ✅ Add comments explaining the use case
- ❌ NEVER duplicate Flyway command logic
- ❌ NEVER copy-paste job definitions

#### When adding new features:
1. Implement in `.gitlab/ci/flyway.yml` as a reusable template
2. Create or update example pipeline demonstrating usage
3. Document in README.md and SETUP_GUIDE.md
4. Ensure backward compatibility with existing examples

### 6. Variable Naming Conventions
**Standard naming (preferred):**
- `TARGET_DATABASE_JDBC` - Full JDBC connection string
- `TARGET_DATABASE_USER` - Database username
- `TARGET_DATABASE_PASSWORD` - Database password
- `TARGET_DATABASE_NAME` - Database name (optional, use when constructing JDBC)
- `TARGET_DATABASE_SERVER` - Server hostname (optional, use when constructing JDBC)

**Pass to Flyway as:**
- `FLYWAY_URL="${TARGET_DATABASE_JDBC}"`
- `FLYWAY_USER="${TARGET_DATABASE_USER}"`
- `FLYWAY_PASSWORD="${TARGET_DATABASE_PASSWORD}"`

### 7. GitLab Setup Method
**Recommended: Import Project** (not "Create from Template")

**Rationale:**
- Users fork/import this repository to get all files and structure
- Maintains git history for updates and improvements
- Easier to pull upstream changes
- Better for version control of their own SQL migrations

**Setup Process:**
1. User imports this repository to their GitLab instance
2. Copy example pipeline: `cp .gitlab-ci-example-dev.yml .gitlab-ci.yml`
3. Configure CI/CD variables in GitLab UI
4. Add SQL migrations to `sql/` directory
5. Commit and push

### 8. Error Handling
Templates should include:
- Clear error messages in `before_script` or `after_script`
- Validation of required variables
- Helpful debugging output (connection strings without passwords)
- Allow manual intervention for dangerous operations (clean, repair)

### 9. Testing Changes
Before committing changes to templates:
1. Test with at least one example pipeline
2. Verify DRY principle: No command duplication
3. Confirm secrets are not exposed in logs
4. Check that variable references are correct
5. Validate YAML syntax

### 10. Documentation Standards
Every change must be reflected in documentation:
- **README.md**: High-level overview, quick start
- **SETUP_GUIDE.md**: Detailed setup instructions, GitLab configuration
- **CLAUDE_INSTRUCTIONS.md**: This file, behavioral guidelines
- **Inline comments**: Explain complex YAML logic

## Common Scenarios

### Scenario: User needs to deploy to 5 databases
**Solution:** Update `.gitlab-ci-example-multi-db.yml` to show explicit jobs for each database

### Scenario: User needs to deploy to 200 databases
**Solution:** Create new example using `parallel:matrix` or dynamic child pipelines

### Scenario: User wants to change Flyway command options globally
**Solution:** Update `.flyway_base` in `.gitlab/ci/flyway.yml` - changes apply everywhere

### Scenario: User wants different SQL locations per database
**Solution:** Override `FLYWAY_LOCATIONS` variable in specific jobs while extending base template

### Scenario: User reports exposed secrets
**Solution:** Verify all secrets use `${VARIABLE}` syntax and are GitLab CI/CD variables, not hardcoded

## Maintenance Checklist
When updating this project:
- [ ] All Flyway commands defined only in `.gitlab/ci/flyway.yml`
- [ ] Example pipelines use `extends`, not duplication
- [ ] No secrets or credentials in code
- [ ] Multi-database support demonstrated
- [ ] README.md updated
- [ ] SETUP_GUIDE.md updated
- [ ] YAML syntax validated
- [ ] Comments added for complex logic
- [ ] Backward compatibility maintained

## Questions to Ask When Uncertain
1. Can this be configured in `.gitlab/ci/flyway.yml` instead of repeating it?
2. Is this secret being stored in GitLab CI/CD variables?
3. Will this work for both 1 database and 100 databases?
4. Is the documentation clear enough for a GitLab beginner?
5. Have I maintained backward compatibility?

## Anti-Patterns to Avoid
- ❌ Copying entire job definitions across multiple files
- ❌ Hardcoding database URLs or credentials
- ❌ Creating separate flyway.yml files for different environments
- ❌ Duplicating Flyway command logic in example pipelines
- ❌ Not documenting variable naming conventions
- ❌ Skipping validation or info commands before migrations
- ❌ Making production deployments automatic without manual approval

---

**Remember**: The goal is to make it as easy as possible for users to adopt this template while maintaining maximum flexibility and security. When in doubt, prioritize DRY principles and user experience.
