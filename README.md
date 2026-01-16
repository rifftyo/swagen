# swagen

`swagen` is a CLI tool to generate Flutter Clean Architecture code from Swagger / OpenAPI specifications.

It helps Flutter developers quickly scaffold:
- Remote data sources
- Repositories
- Models & entities
- Failures & exceptions

based on OpenAPI 3.x documents.

---

## Features

- 🚀 Generate Flutter Clean Architecture structure
- 📄 OpenAPI 3.x / Swagger support
- 🔐 Security & authorization detection
- 📦 Supports:
  - Path parameters
  - Query parameters
  - Request body
  - Multipart form data (file upload)
- 🧩 Generates:
  - Datasource
  - Repository
  - Repository implementation
  - Models & entities
- 🛠 CLI-based tool

---

## Getting Started

### Prerequisites
- Dart SDK >= 3.0
- Flutter project (recommended)

---

## Installation

Activate `swagen` globally:

```bash
dart pub global activate swagen
