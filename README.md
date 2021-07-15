# Automated testing of DB changes in CI/CD pipelines using thin clones provided by Database Lab (Postgres.ai)



## Overview
This GitHub action tests database schema changes (DB migrations) automatically using thin clones of large databases provided by Database Lab Engine (DLE).

[**Database Lab Engine**](https://postgres.ai/docs/database-lab) is an open-source technology that is a core component of the Database Lab Platform. It is used to build powerful, state-of-the-art development and testing environments, based on a simple idea: with modern thin cloning technologies, it becomes possible to iterate 100x faster in development and testing. It is extremely helpful for larger or small but very agile teams that want to achieve high development velocity and the most competitive "time to market" characteristics and save budgets on non-production infrastructure.

[**Database Lab DB Migration Checker**](https://postgres.ai/docs/db-migration-checker) is a DLE's component that enables integration with CI/CD tools to automatically test migrations in CI/CD pipelines.

## Key features
- **Automated:** DB migration testing in CI/CD pipelines
- **Realistic:** test results are realistic because real or close-to-real (the same size but no personal data) databases are used, thin-cloned in seconds, and destroyed after testing is done
- **Fast and inexpensive:** a single machine with a single disk can operate dozens of independent thin clones
- **Well-tested DB changes to avoid deployment failures:** DB Migration Checker automatically detects (and prevents!) long-lasting dangerous locks that could put your production systems down
- **Secure**: DB Migration Checker runs all tests in a secure environment: data cannot be copied outside the secure container
- **Lots of useful data points**: Collect useful artifacts (such as `pg_stat_***` system views) and use them to empower your DB changes review process

## How to use
To use the action, create a YAML file in the `.github/workflows/` directory.

Copy and paste the installation snippet from the [Marketplace page](https://github.com/marketplace/actions/database-lab-migration-checker) into your `.yml` file.

Check out the docs to learn more:
- [DB Migration Checker. How to test DB changes in CI/CD automatically](https://postgres.ai/docs/db-migration-checker)
- [DB Migration Checker configuration reference](https://postgres.ai/docs/reference-guides/db-migration-checker-configuration-reference)

YAML file example:
```yaml
on: [ push ]

jobs:
  migration_job:
    runs-on: ubuntu-latest
    name: CI migration
    steps:
      # Checkout the source code
      - name: Checkout
        uses: actions/checkout@v2

      # Run database migrations with the public action
      - name: Check database migrations with DLE
        uses: postgres-ai/dle-github-action@v0.1.1
        id: db-migrations
        with:
          dbname: test
          commands: |
            sqitch deploy
            echo 'Migration has been completed'
          download_artifacts: true
          observation_interval: "10"
          max_lock_duration: "1"
          max_duration: "600"
        env:
          DLMC_CI_ENDPOINT: ${{ secrets.DLMC_CI_ENDPOINT }}
          DLMC_VERIFICATION_TOKEN: ${{ secrets.DLMC_VERIFICATION_TOKEN }}

      # Download artifacts
      - name: Upload artifacts
        uses: actions/upload-artifact@v2
        with:
          name: artifacts
          path: artifacts/*
          if-no-files-found: ignore
        if: always()

      # Show migration summary
      - name: Get the response status
        run: echo "${{ steps.db-migrations.outputs.response }}"
```
