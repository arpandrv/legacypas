# CLAUDE.md - Guidelines for this codebase

## Build/Run Commands
- Compile using Delphi/Lazarus: `lazbuild claim.pas` or through the IDE
- Run the application: Execute the compiled binary

## Code Style Guidelines

### Naming Conventions
- Use camelCase for variables and procedures (e.g., `ssf_booking_show`, `refreshqry4`)
- Use PascalCase for classes and components (e.g., `TSSFPatientSalesList_frm`)
- Prefix global variables with 'g' (e.g., `gfirmname`, `gaddress`)

### Structure
- Use proper indentation (2 spaces)
- Use `begin`/`end` blocks for all control structures
- Always include empty `begin`/`end` blocks for empty conditions

### Error Handling
- Use `try`/`finally` blocks for resource cleanup
- Always free created objects (e.g., `selectqry.Destroy`)
- Use `exit` to terminate procedure when validation fails

### Pascal Specifics
- Use `with` statements sparingly
- Use strongly typed variables
- Free objects in `finally` blocks or immediately after use

### Comments
- Use comments for non-obvious logic
- Include TODO comments for incomplete functionality