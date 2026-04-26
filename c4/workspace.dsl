workspace "Sample Workspace" "A sample workspace to test Structurizr." {

    model {
        user = person "User" "A user of my software system."
        softwareSystem = softwareSystem "Software System" "My software system." {
            webapp = container "Web Application" "Delivers the static content and the single page application." "Java and Spring Boot"
            database = container "Database" "Stores user registration information, hashed authentication credentials, access logs, etc." "Relational Database Schema" "Database"
        }

        user -> webapp "Uses" "HTTPS"
        webapp -> database "Reads from and writes to" "JDBC"
    }

    views {
        systemContext softwareSystem "SystemContext" {
            include *
            autoLayout
        }

        container softwareSystem "Containers" {
            include *
            autoLayout
        }

        theme default
    }

}