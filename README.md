# Swagen - Swagger to Flutter Clean Architecture Generator

Swagen is a powerful code generator that converts **Swagger/OpenAPI 3.0** specifications into a fully structured **Flutter project** following **Clean Architecture** principles.  

With Swagen, you can automatically generate:

- Models & Entities
- Remote DataSources
- Repositories & Repository Implementations
- UseCases
- Providers
- GetIt Injector for dependency management

It supports **Swagger v3 input** from:

- Local JSON files (`swagger.json`)
- Local YAML files (`swagger.yaml`)
- Remote URLs (`https://example.com/swagger.json`)

Swagen simplifies the process of turning an API specification into a ready-to-use Flutter application with clean and maintainable architecture.

## Usage

Swagen can be installed **locally** in a Flutter project or **globally** on your system. The usage differs slightly depending on the installation method.

### Local Installation (Project-Specific)

Install Swagen in your Flutter project:

```bash
flutter pub add swagen
```
Run the generator using dart run:
#### Convert a local Swagger file
```bash
dart run swagen convert path/to/swagger.json
```
#### Convert from a URL
```bash
dart run swagen convert https://example.com/swagger.json
```

### Global Installation (System-Wide)

Install Swagen in your Flutter project:

```bash
dart pub global activate swagen
```
Run the generator using dart run:
#### Convert a local Swagger file
```bash
swagen convert path/to/swagger.json
```
#### Convert from a URL
```bash
swagen convert https://example.com/swagger.json
```

## Features

### 1. Auto-generated Clean Architecture Layers
For each feature in your API, Swagen generates:

- **Data Layer**
  - `Models` for API responses
  - `RemoteDataSource` using `http` client and `FlutterSecureStorage` for token handling
  - `RepositoryImpl` implementing the feature repository interface
- **Domain Layer**
  - `Entities` representing your core business objects
  - `Repository` interface
  - `UseCases` encapsulating business logic
- **Presentation Layer**
  - `Providers` for state management (using `ChangeNotifier`)

### 2. Dependency Injection
- Generates a ready-to-use `injector.dart` with **GetIt**.
- All Providers, UseCases, Repositories, and DataSources are registered automatically.
- Supports **lazy singletons** for UseCases and Repositories and **factories** for Providers.

### 3. Security Support
- Handles **Bearer Token authentication** automatically.
- Uses `FlutterSecureStorage` to store JWT tokens securely.
- DataSource automatically attaches tokens to requests if configured.

### 4. HTTP Requests
- Uses `http` package for all API calls.
- Supports GET, POST, PUT, PATCH, DELETE methods.
- Automatically converts JSON responses into **strongly typed Models** and Entities.

### 5. Swagger / OpenAPI Support
- Accepts local `.json` file or URL.
- Supports:
  - Parameters (query, path, header)
  - Inline schemas
  - Nested entities
- Auto-generates method names and UseCases based on `operationId` or endpoint path.

## Command

Swagen can generate a Flutter Clean Architecture project from a Swagger/OpenAPI file, either from a local JSON file or a remote URL. Below are the commands and explanations:

### 1. Generate from a local Swagger file
```bash
dart run swagen convert path/swagger.json
```
- `dart run swagen convert` → Runs the Swagen converter.
- `path/swagger.json` → Path to your local Swagger/OpenAPI JSON file.
- Generates models, entities, repositories, usecases, providers, and injector automatically.

### 2. Generate from a remote Swagger URL
```bash
dart run swagen convert https://example.com/swagger.json
```
- `https://example.com/swagger.json` → URL of the Swagger/OpenAPI JSON file.
- Useful if your API specification is hosted online.
- Everything else is generated the same as the local file command.

### 3. Specify a custom package name
```bash
dart run swagen convert swagger.json --package music_app
```
- `--package music_app` → Sets the package name used in import statements and generated code.
- Example: Instead of default package name from `pubspec.yaml`, it will use `music_app` in imports.

### 4. Generate Clean Architecture interactively
```bash
dart run swagen cleanarch
```
- Prompts you to enter the **number of features** in your API
- Asks for **feature names** one by one (e.g., `auth`, `user`, `artist`).
- Generates:
  - Data Layer: models, - datasources, repositories
  - Domain Layer: entities, repositories, usecases
  - Presentation Layer: providers

### 5. Help command
```bash
dart run swagen help
```
- Displays all available commands with explanations.

### 6. Version command
```bash
dart run swagen version
```
- Displays the current version of Swagen.
- Shows the GitHub repository link for updates and issues.

## Project Structure

After running Swagen, your Flutter project will have a clean architecture structure like this:

```bash
📦core
 ┣ 📂error
 ┃ ┣ 📜exception.dart
 ┃ ┗ 📜failure.dart
 ┗ 📂state
 ┃ ┗ 📜request_state.dart
📦features
 ┣ 📂pet
 ┃ ┣ 📂data
 ┃ ┃ ┣ 📂datasources
 ┃ ┃ ┃ ┗ 📜remote_data_source.dart
 ┃ ┃ ┣ 📂models
 ┃ ┃ ┃ ┣ 📜api_response.dart
 ┃ ┃ ┃ ┣ 📜category_response.dart
 ┃ ┃ ┃ ┣ 📜pet_list_response.dart
 ┃ ┃ ┃ ┣ 📜pet_response.dart
 ┃ ┃ ┃ ┗ 📜tag_response.dart
 ┃ ┃ ┗ 📂repositories
 ┃ ┃ ┃ ┗ 📜pet_repository.dart
 ┃ ┣ 📂domain
 ┃ ┃ ┣ 📂entities
 ┃ ┃ ┃ ┣ 📜api.dart
 ┃ ┃ ┃ ┣ 📜category.dart
 ┃ ┃ ┃ ┣ 📜pet.dart
 ┃ ┃ ┃ ┗ 📜tag.dart
 ┃ ┃ ┣ 📂repositories
 ┃ ┃ ┃ ┗ 📜pet_repository.dart
 ┃ ┃ ┗ 📂usecases
 ┃ ┃ ┃ ┣ 📜add_pet.dart
 ┃ ┃ ┃ ┣ 📜delete_pet.dart
 ┃ ┃ ┃ ┣ 📜find_pets_by_status.dart
 ┃ ┃ ┃ ┣ 📜find_pets_by_tags.dart
 ┃ ┃ ┃ ┣ 📜get_pet_by_id.dart
 ┃ ┃ ┃ ┣ 📜update_pet.dart
 ┃ ┃ ┃ ┣ 📜update_pet_with_form.dart
 ┃ ┃ ┃ ┗ 📜upload_file.dart
 ┃ ┗ 📂presentation
 ┃ ┃ ┗ 📂providers
 ┃ ┃ ┃ ┣ 📜add_pet_provider.dart
 ┃ ┃ ┃ ┣ 📜delete_pet_provider.dart
 ┃ ┃ ┃ ┣ 📜find_pets_by_status_provider.dart
 ┃ ┃ ┃ ┣ 📜find_pets_by_tags_provider.dart
 ┃ ┃ ┃ ┣ 📜get_pet_by_id_provider.dart
 ┃ ┃ ┃ ┣ 📜update_pet_provider.dart
 ┃ ┃ ┃ ┣ 📜update_pet_with_form_provider.dart
 ┃ ┃ ┃ ┗ 📜upload_file_provider.dart
 ┣ 📂store
 ┃ ┣ 📂data
 ┃ ┃ ┣ 📂datasources
 ┃ ┃ ┃ ┗ 📜remote_data_source.dart
 ┃ ┃ ┣ 📂models
 ┃ ┃ ┃ ┗ 📜order_response.dart
 ┃ ┃ ┗ 📂repositories
 ┃ ┃ ┃ ┗ 📜store_repository.dart
 ┃ ┣ 📂domain
 ┃ ┃ ┣ 📂entities
 ┃ ┃ ┃ ┗ 📜order.dart
 ┃ ┃ ┣ 📂repositories
 ┃ ┃ ┃ ┗ 📜store_repository.dart
 ┃ ┃ ┗ 📂usecases
 ┃ ┃ ┃ ┣ 📜delete_order.dart
 ┃ ┃ ┃ ┣ 📜get_inventory.dart
 ┃ ┃ ┃ ┣ 📜get_order_by_id.dart
 ┃ ┃ ┃ ┗ 📜place_order.dart
 ┃ ┗ 📂presentation
 ┃ ┃ ┗ 📂providers
 ┃ ┃ ┃ ┣ 📜delete_order_provider.dart
 ┃ ┃ ┃ ┣ 📜get_inventory_provider.dart
 ┃ ┃ ┃ ┣ 📜get_order_by_id_provider.dart
 ┃ ┃ ┃ ┗ 📜place_order_provider.dart
 ┗ 📂user
 ┃ ┣ 📂data
 ┃ ┃ ┣ 📂datasources
 ┃ ┃ ┃ ┗ 📜remote_data_source.dart
 ┃ ┃ ┣ 📂models
 ┃ ┃ ┃ ┗ 📜user_response.dart
 ┃ ┃ ┗ 📂repositories
 ┃ ┃ ┃ ┗ 📜user_repository.dart
 ┃ ┣ 📂domain
 ┃ ┃ ┣ 📂entities
 ┃ ┃ ┃ ┗ 📜user.dart
 ┃ ┃ ┣ 📂repositories
 ┃ ┃ ┃ ┗ 📜user_repository.dart
 ┃ ┃ ┗ 📂usecases
 ┃ ┃ ┃ ┣ 📜create_user.dart
 ┃ ┃ ┃ ┣ 📜create_users_with_list_input.dart
 ┃ ┃ ┃ ┣ 📜delete_user.dart
 ┃ ┃ ┃ ┣ 📜get_user_by_name.dart
 ┃ ┃ ┃ ┣ 📜login_user.dart
 ┃ ┃ ┃ ┣ 📜logout_user.dart
 ┃ ┃ ┃ ┗ 📜update_user.dart
 ┃ ┗ 📂presentation
 ┃ ┃ ┗ 📂providers
 ┃ ┃ ┃ ┣ 📜create_users_with_list_input_provider.dart
 ┃ ┃ ┃ ┣ 📜create_user_provider.dart
 ┃ ┃ ┃ ┣ 📜delete_user_provider.dart
 ┃ ┃ ┃ ┣ 📜get_user_by_name_provider.dart
 ┃ ┃ ┃ ┣ 📜login_user_provider.dart
 ┃ ┃ ┃ ┣ 📜logout_user_provider.dart
 ┃ ┃ ┃ ┗ 📜update_user_provider.dart
 ```