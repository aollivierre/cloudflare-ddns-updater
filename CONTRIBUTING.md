# Contributing to Cloudflare DDNS Updater

First off, thank you for considering contributing to Cloudflare DDNS Updater! It's people like you that make this tool better for everyone.

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

* Use a clear and descriptive title
* Describe the exact steps to reproduce the problem
* Provide specific examples to demonstrate the steps
* Describe the behavior you observed after following the steps
* Explain which behavior you expected to see instead and why
* Include logs and configuration (remove sensitive data!)
* Include details about your environment (OS, PowerShell/Python version, etc.)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

* Use a clear and descriptive title
* Provide a step-by-step description of the suggested enhancement
* Provide specific examples to demonstrate the steps
* Describe the current behavior and explain which behavior you expected to see instead
* Explain why this enhancement would be useful

### Pull Requests

1. Fork the repo and create your branch from `main` (for Windows) or `linux-native` (for Linux)
2. If you've added code that should be tested, add tests
3. If you've changed APIs, update the documentation
4. Ensure the test suite passes
5. Make sure your code follows the existing style
6. Issue that pull request!

## Development Process

### Windows (PowerShell)

1. Fork and clone the repository
2. Create a new branch: `git checkout -b feature/your-feature-name`
3. Make your changes in the PowerShell modules
4. Test thoroughly on Windows 10/11
5. Update documentation as needed
6. Commit your changes: `git commit -am 'Add some feature'`
7. Push to the branch: `git push origin feature/your-feature-name`
8. Submit a pull request to the `main` branch

### Linux (Python)

1. Fork and clone the repository
2. Switch to linux-native branch: `git checkout linux-native`
3. Create a new branch: `git checkout -b feature/your-feature-name`
4. Make your changes in the Python code
5. Test thoroughly on your Linux distribution
6. Update documentation as needed
7. Commit your changes: `git commit -am 'Add some feature'`
8. Push to the branch: `git push origin feature/your-feature-name`
9. Submit a pull request to the `linux-native` branch

## Styleguides

### Git Commit Messages

* Use the present tense ("Add feature" not "Added feature")
* Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
* Limit the first line to 72 characters or less
* Reference issues and pull requests liberally after the first line

### PowerShell Styleguide

* Follow [PowerShell Best Practices](https://poshcode.gitbooks.io/powershell-practice-and-style/)
* Use approved verbs for function names
* Include comment-based help for all functions
* Use proper error handling with try/catch blocks

### Python Styleguide

* Follow [PEP 8](https://www.python.org/dev/peps/pep-0008/)
* Use type hints where appropriate
* Include docstrings for all functions and classes
* Use meaningful variable names

### Documentation Styleguide

* Use [Markdown](https://guides.github.com/features/mastering-markdown/)
* Reference functions and variables in backticks: `functionName()`
* Include code examples where helpful
* Keep line length to 80 characters where possible

## Testing

### Windows Testing

```powershell
# Run the script in test mode
.\Update-CloudflareDDNS.ps1 -TestMode

# Verify scheduled task
Get-ScheduledTask -TaskName "CloudflareDDNS"
```

### Linux Testing

```bash
# Test configuration
python3 cloudflare_ddns.py --config test-config.json --once

# Check service syntax
systemd-analyze verify cloudflare-ddns.service
```

## Questions?

Feel free to open an issue with your question or contact the maintainers directly.

Thank you for contributing! 🎉