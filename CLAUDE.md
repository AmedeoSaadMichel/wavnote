# FLUTTER VOICE MEMO APP PROJECT RULES

## CRITICAL: File Structure Compliance

- **Always write in English.**
- **When I ask you to fix the errors, you can change the logic but you must ask before making any logic changes.**
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

- **Maintain clean, modern UI design** with standard Material Design principles
- Use consistent color schemes throughout the app (whites, greys, standard accent colors)
- Avoid cosmic/mystical themes in favor of professional, user-friendly design
- Focus on clarity, usability, and intuitive user experience
- **NO copyrighted material** - all design elements must be original

## CRITICAL: BLoC Architecture Preservation

- **NEVER remove or modify BLoC logic** when making UI changes
- Always preserve BlocBuilder, BlocConsumer, and BlocListener widgets
- Maintain all callback functions that connect UI to BLoC events
- When refactoring UI components, ensure BLoC integration remains intact
- Separate UI styling changes from business logic - only modify visual elements

## CRITICAL: Responsive UI Development

- **ALWAYS use responsive widgets** when building UI layouts
- Prioritize Flexible, Expanded, and FractionallySizedBox over fixed sizes
- Use MediaQuery for screen-dependent measurements when necessary
- Implement proper flex values in Column and Row widgets
- Avoid hardcoded pixel values - use relative sizing and spacing
- Ensure UI adapts gracefully to different screen sizes and orientations
- Test layouts on various device sizes during development

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
- Ensure UI/UX consistency in all screens and widgets
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
6. Ensure changes align with existing project patterns
7. Verify that no copyrighted material is referenced

---

## PROJECT CONTEXT

**WavNote** is a Flutter voice memo application. The app focuses on creating a user-friendly experience for audio recording and organization.

### Architecture
- **Clean Architecture** with clear separation of concerns
- **BLoC Pattern** for state management
- **Repository Pattern** for data access
- **Use Case Pattern** for business logic

### Key Features
- Audio recording with geolocation-based naming
- Folder-based organization
- Advanced search and filtering
- Clean UI with smooth animations
- Export and sharing capabilities

### Development Status
- Core recording/playback functionality complete
- File management services implemented
- Geolocation-based recording naming
- Advanced search and filtering system