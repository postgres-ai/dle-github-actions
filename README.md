# Database Lab (Postgres.ai) to test DB migrations in CI

This GitHub action tests DB migrations database schema changes (database migrations) automatically using thin clones of large databases provided by Database Lab Engine (DLE)

## Overview
**Database Lab DB migration checker** is a tool to automatically test migrations in CI/CD pipelines.

## Key features
- Check migrations as a part of a standard CI/CD pipeline
- Automatically detect (and prevent!) long-lasting dangerous locks that could put your production systems down
- Run all tests in secure environment: data cannot be copied to outside of a secured container
- Collect useful artifacts (such as `pg_stat_***` system views) and use them to enpower your DB changes review process

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
        uses: postgres-ai/migration-ci-action@v0.1.1
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
