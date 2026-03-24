---
name: codebase-summary
description: Analyze a codebase and generate structured documentation describing system architecture, components, interfaces, and workflows. Use when the user wants to document, summarize, or understand a codebase's architecture, or generate a knowledge base for AI assistants to reference during development tasks.
---

# Codebase Summary

## Overview

Analyze a codebase and generate structured documentation covering architecture, components, interfaces, data models, workflows, and dependencies. The output is organized as a knowledge base that AI assistants can reference to understand the system and assist with development.

## Parameters

- **agents_dir** (optional, default: `.agents`): Base directory for all structured-spec-to-code workflow artifacts
- **codebase_summary_dir** (optional, default: `{agents_dir}/summary`): Directory where codebase summary documentation will be stored
- **codebase_path** (optional, default: current directory): Path to the codebase to analyze
- **update_mode** (optional, default: true if codebase_summary_dir already contains a summary, false otherwise): Whether to update existing documentation based on recent changes, or perform a full analysis

**Constraints for parameter acquisition:**
- You MUST ask for all parameters upfront in a single prompt rather than one at a time
- You MUST validate that the codebase_path exists and is accessible
- You MUST confirm successful acquisition of all parameters before proceeding

## Steps

### 1. Setup and Directory Structure

Initialize the analysis environment and create necessary directory structure.

**Constraints:**
- You MUST create the output_dir if it doesn't exist
- You MUST inform the user about the directory structure being created
- If update_mode is true, you MUST:
  - Check if {codebase_summary_dir}/last_commit exists to determine the baseline revision
  - Use version control history to review commits since the baseline and identify changes
- If update_mode is false or no previous documentation exists, you MUST inform the user that full analysis will be performed

### 2. Analyze Codebase Structure

Perform comprehensive analysis of the codebase to understand its structure, components, and relationships.

**Constraints:**
- You MUST use available code navigation and analysis tools (e.g., indexing tools, search skills, MCP servers) to gather information about the codebase structure, especially in large or monorepo codebases
- You MUST identify all packages, modules, and major components in the codebase
- You MUST analyze file organization, directory structure, and architectural patterns
- You MUST identify programming languages used
- You MUST document the technology stack and dependencies
- You MUST identify key interfaces, APIs, and integration points
- You MUST analyze code patterns and design principles used throughout the codebase
- You MUST analyze coding style and conventions, including:
  - Naming conventions (variables, functions, classes, files, directories)
  - Code structure patterns (how typical modules/classes/files are organized — imports, constants, class/function ordering)
  - Error handling idioms (how errors are created, propagated, reported)
  - Testing conventions (test file naming, test structure, assertion style, fixture/mock approach)
  - Logging and observability patterns
  - Import and dependency conventions
- You MUST examine linter, formatter, and editor configuration files (e.g., `.editorconfig`, `.eslintrc*`, `.prettierrc*`, `pyproject.toml`, `rustfmt.toml`, `.clang-format`, etc.) and document what they enforce
- You MUST ask the user whether explicit coding style guides or style reference skills are available for the languages used in the codebase, unless these can be inferred from project configuration (e.g., a linter config referencing a specific style guide)
- You MUST identify representative code examples — specific files that exemplify the codebase's conventions for common patterns (e.g., "a typical request handler", "a typical unit test", "a typical data model") — and record their paths
- You MUST use Mermaid diagrams for visual representations
- You MUST document basic codebase information in {codebase_summary_dir}/codebase_info.md
- If update_mode is true, you MUST:
  - Analyze which packages and files were modified in recent commits
  - Prioritize analysis of modified components
  - Create a change summary document listing all relevant changes since last update

### 3. Generate Documentation Files

Create comprehensive documentation files for different aspects of the system.

**Constraints:**
- You MUST create a comprehensive knowledge base index file ({codebase_summary_dir}/index.md) that:
  - Provides explicit instructions for AI assistants on how to use the documentation
  - Contains rich metadata about each file's purpose and content
  - Includes a table of contents with descriptive summaries for each document
  - Explains relationships between different documentation files
  - Guides AI assistants on which files to consult for specific types of questions
  - Contains brief summaries of each file's content to help determine relevance
  - Is designed to be the primary file needed in context for AI assistants to effectively answer questions
- You MUST create documentation files for different aspects of the system:
  - {codebase_summary_dir}/architecture.md (system architecture and design patterns)
  - {codebase_summary_dir}/components.md (major components and their responsibilities)
  - {codebase_summary_dir}/interfaces.md (APIs, interfaces, and integration points)
  - {codebase_summary_dir}/data_models.md (data structures and models)
  - {codebase_summary_dir}/workflows.md (key processes and workflows)
  - {codebase_summary_dir}/dependencies.md (external dependencies and their usage)
  - {codebase_summary_dir}/coding_style.md (coding conventions, style rules, and representative examples)
- You MUST ensure the coding_style.md file includes:
  - A summary of enforced style rules from linter/formatter configs
  - References to external style guides (if identified or provided by the user)
  - Inferred conventions for naming, structure, error handling, testing, logging, and imports — each with concrete examples drawn from the codebase
  - A "Representative Examples" section with file paths pointing to files that best exemplify each common pattern (e.g., request handler, unit test, integration test, data model, utility module), with a brief note on why each was chosen
- You MUST ensure each documentation file contains relevant information from the codebase analysis
- If update_mode is true, you MUST:
  - Preserve existing documentation structure where possible
  - Only update sections related to modified components

### 4. Review Documentation

Review the documentation for consistency and completeness.

**Constraints:**
- You MUST check for inconsistencies across documents
- You MUST identify areas lacking sufficient detail
- You MUST document any inconsistencies or gaps found in {codebase_summary_dir}/review_notes.md
- You SHOULD use insights from the codebase analysis to identify areas needing more detail
- You MUST provide recommendations for improving documentation quality

### 5. Summary and Next Steps

Provide a summary of the documentation process and suggest next steps.

**Constraints:**
- You MUST save the current revision identifier (e.g., commit hash) to {codebase_summary_dir}/last_commit to enable future update_mode runs
- You MUST summarize what has been accomplished
- You MUST suggest next steps for using the documentation
- You MUST provide guidance on maintaining and updating the documentation
- You MUST include specific instructions for adding the documentation to AI assistant context:
  - Recommend using the index.md file as the primary context file
  - Explain how AI assistants can leverage the index.md file as a knowledge base to find relevant information
  - Emphasize that the index.md contains sufficient metadata for assistants to understand which files contain detailed information
  - Provide example queries that demonstrate how to effectively use the documentation
- If update_mode was used, you MUST:
  - Summarize what changes were detected and updated in the documentation
  - Highlight any significant architectural changes
  - Recommend areas that might need further manual review

## Examples

### Example Input
```
codebase_summary_dir: ".agents/summary"
codebase_path: "/path/to/project"
```

### Example Output (Generate Mode)
```
Setting up directory structure...
✅ Created directory .agents/summary/
✅ Created subdirectories for documentation artifacts

Analyzing codebase structure...
✅ Found 15 packages across 3 programming languages
✅ Identified 45 major components and 12 key interfaces
✅ Codebase information saved to .agents/summary/codebase_info.md

Generating documentation files...
✅ Created index.md with knowledge base metadata
✅ Generated architecture.md, components.md, interfaces.md
✅ Generated data_models.md, workflows.md, dependencies.md
✅ Generated coding_style.md with conventions and representative examples

Reviewing documentation...
✅ Consistency check complete
✅ Completeness check complete
✅ Review notes saved to .agents/summary/review_notes.md

Summary and Next Steps:
✅ Documentation generation complete!
✅ To use with AI assistants, add .agents/summary/index.md to context
```

### Example Output (Update Mode)
```
Update mode detected - checking for changes...
✅ Found existing documentation
✅ Identified 8 commits since last update affecting 3 packages

Analyzing recent changes...
✅ Updated components: AuthService, DataProcessor, APIGateway
✅ Change summary saved to .agents/summary/recent_changes.md

Updating documentation...
✅ Updated architecture.md with new AuthService patterns
✅ Updated components.md with DataProcessor changes
✅ Updated interfaces.md with new API endpoints

Summary:
✅ Documentation updated based on 8 recent commits
✅ 3 major components updated in documentation
✅ Review .agents/summary/recent_changes.md for detailed change summary
```

### Example Output Structure
```
{codebase_summary_dir}/
├── last_commit (revision identifier for update_mode baseline)
├── index.md (knowledge base index)
├── codebase_info.md
├── architecture.md
├── components.md
├── interfaces.md
├── data_models.md
├── workflows.md
├── dependencies.md
├── coding_style.md
├── review_notes.md
└── recent_changes.md (if update_mode)
```

## Troubleshooting

### Large Codebase Performance
For very large codebases that take significant time to analyze:
- You SHOULD provide progress updates during analysis
- You SHOULD suggest focusing on specific directories or components if performance becomes an issue

### Update Mode Issues
If update mode fails to detect changes correctly:
- Check if version control history is available and accessible
- Try running with update_mode=false to generate fresh documentation

### Missing Documentation Sections
If certain aspects of the codebase are not well documented:
- Check the review_notes.md file for identified gaps
- Review the codebase analysis to ensure all components were properly identified

### Version Control Integration Problems
If version control commands fail during update mode:
- Ensure the codebase_path is within a valid repository
- Check that the VCS tooling is installed and accessible
- Verify that the user has appropriate permissions to read revision history