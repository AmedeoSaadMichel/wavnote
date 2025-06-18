# FLUTTER VOICE MEMO APP PROJECT RULES

## CRITICAL: File Structure Compliance

- **Always write in English.**
- **When I ask you to fix the errors, you must never change the logic.**
- **Always follow the exact structure defined in idea_project_structure.txt**
- It isn't necessary to create all the files in the idea_project_structure.txt; we only need the essential ones.
- Structure changes are allowed ONLY when it's impossible to keep files under 500 lines
- When structure changes are made due to file size constraints:
  - Explain why the change was necessary
  - ALWAYS provide the complete updated idea_project_structure.txt file
  - Ensure the new structure maintains logical organisation

## CRITICAL: File Size Limit

- **Maximum 500 lines per file** - If a file exceeds 500 lines, it MUST be refactored
- If refactoring within current structure is impossible, then and only then modify the project structure
- Break oversized files into smaller, focused components following single responsibility principle

## CRITICAL: Theme Guidelines

- **Midnight Gospel Inspired Theme** - App design and content should evoke mystical, cosmic, and philosophical vibes
- Use original cosmic/mystical aesthetics (dark cosmic backgrounds, ethereal colors, celestial imagery)
- Incorporate philosophical and introspective elements in UI copy and user experience
- Create original spiritual/cosmic visual elements (avoid direct references to copyrighted material)
- Focus on themes of: consciousness, meditation, cosmic exploration, inner journey, mystical experiences
- **NO copyrighted material** - all theme elements must be original interpretations

## MANDATORY: File Path Comments

- **EVERY edited file MUST include a path comment at the very beginning**
- Format: `// File: [exact/path/to/file.dart]`
- Example: `// File: presentation/screens/recording/recording_entry_screen.dart`
- This comment is required for ALL code files without exception

## MANDATORY: Structure File Updates

- **EVERY time ANY file is added to the project, provide BOTH updated files:**
  - Complete updated idea_project_structure.txt
  - Complete updated project_structure.txt
- **EVERY time idea_project_structure.txt is modified, provide the complete updated file**
- No exceptions - both structure files must always be delivered when files are added
- Clearly indicate what changes were made and why

## PRIMARY: Consistency Requirements

- Maintain consistent coding patterns throughout the project
- Follow established naming conventions from existing files
- Keep architectural patterns uniform across all components
- Ensure UI/UX consistency in all screens and widgets with mystical/cosmic theme
- Maintain thematic coherence across all user-facing elements

## SECONDARY: Development Approach

- Always reference the project structure before making changes
- Verify file placement matches the defined architecture
- Maintain the separation of concerns as outlined in the structure
- Follow Flutter best practices for state management and widget organisation
- Consider thematic elements when naming variables, classes, and UI components

## WORKFLOW: Before Every Code Change

1. Check idea_project_structure.txt for correct file placement
2. Add the mandatory file path comment
3. Verify the file won't exceed 500 lines after changes
4. If adding new files, prepare updated idea_project_structure.txt AND project_structure.txt
5. If 400+ lines are unavoidable, restructure and provide updated structure files
6. Ensure changes align with existing project patterns and the cosmic theme
7. Verify that no copyrighted material is referenced

---

## PROJECT CONTEXT

**WavNote** is a Flutter voice memo application with a mystical, cosmic theme inspired by The Midnight Gospel aesthetic. The app focuses on creating a transcendent user experience for audio recording and organization.

### Architecture
- **Clean Architecture** with clear separation of concerns
- **BLoC Pattern** for state management
- **Repository Pattern** for data access
- **Use Case Pattern** for business logic

### Key Features
- Audio recording with cosmic visualizations
- Folder-based organization
- Advanced search and filtering
- Mystical UI with ethereal animations
- Export and sharing capabilities

### Development Status
- 104+ files implemented (~69% complete)
- Core recording/playback functionality complete
- File management services implemented
- Cosmic theming throughout UI
- Advanced search and filtering system