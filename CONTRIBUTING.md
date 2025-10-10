# Contributing to DPC Maven Repository

Thank you for your interest in contributing to the Dan's Plugins Community Maven Repository!

## How to Contribute

### Reporting Issues

If you encounter any problems or have suggestions for improvements:

1. Check if the issue already exists in the [Issues](https://github.com/Dans-Plugins/dpc-mvn-repo/issues) section
2. If not, create a new issue with:
   - A clear, descriptive title
   - Detailed description of the problem or suggestion
   - Steps to reproduce (if applicable)
   - Your environment details (OS, Docker version, etc.)

### Proposing Changes

1. Fork the repository
2. Create a new branch for your changes: `git checkout -b feature/your-feature-name`
3. Make your changes following the guidelines below
4. Test your changes thoroughly
5. Commit your changes with clear, descriptive messages
6. Push to your fork: `git push origin feature/your-feature-name`
7. Open a Pull Request with a clear description of the changes

## Development Guidelines

### File Organization

```
dpc-mvn-repo/
├── docker-compose.yml           # Main orchestration file
├── Dockerfile                   # Custom Nexus image
├── setup.sh                     # Setup automation
├── backup.sh                    # Backup automation
├── restore.sh                   # Restore automation
├── Makefile                     # Convenience commands
├── settings.xml.template        # Maven settings template
├── pom.xml.template             # POM configuration template
└── README.md                    # Main documentation
```

### Code Style

- Use clear, descriptive variable names
- Add comments for complex logic
- Follow shell script best practices (use shellcheck)
- Keep Dockerfile instructions minimal and ordered efficiently

### Testing Changes

Before submitting a PR:

1. Validate Docker Compose configuration:
   ```bash
   docker compose config --quiet
   ```

2. Test the setup process:
   ```bash
   ./setup.sh
   ```

3. Verify the repository starts correctly:
   ```bash
   make start
   make status
   ```

4. Test backup and restore (if applicable):
   ```bash
   make backup
   ```

5. Clean up test environment:
   ```bash
   make clean
   ```

### Documentation

- Update README.md if you add new features or change existing behavior
- Keep documentation clear, concise, and accurate
- Include examples where helpful
- Update templates if configuration changes

### Commit Messages

- Use present tense: "Add feature" not "Added feature"
- Use imperative mood: "Move file to..." not "Moves file to..."
- Reference issues when applicable: "Fix #123: Description"
- Keep first line under 72 characters

Examples:
- `Add backup rotation script`
- `Fix healthcheck timeout issue`
- `Update documentation for production deployment`
- `Improve error handling in setup.sh`

## Pull Request Process

1. Ensure all tests pass
2. Update documentation as needed
3. Add a clear description of what your PR does
4. Link any related issues
5. Request review from maintainers
6. Address any feedback promptly

## Security

If you discover a security vulnerability:

1. **Do NOT** open a public issue
2. Email the maintainers privately
3. Include details about the vulnerability and potential impact
4. Allow time for the issue to be addressed before public disclosure

## Questions?

If you have questions about contributing:

- Open a discussion in the repository
- Check existing issues and PRs for similar questions
- Reach out to maintainers

## License

By contributing, you agree that your contributions will be licensed under the same terms as the project.

## Thank You!

Your contributions help make this project better for the entire Dan's Plugins Community!
