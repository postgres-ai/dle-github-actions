# DB Migrations checking action

A GitHub action to run DB migrations with Database Lab Engine (DLE) 

## Overview
**Database Lab DB migration checker** is a tool to automatically validate migrations in the CI pipeline.

## Database Lab DB migration checker's benefits:
- Check migrations as a part of a standard pipeline
- Protect DLE from data stealing - run migrations in a protected environment
- Protect logs and artifacts from being revealed

## How to use
To use the action, create a yml file in the `.github/workflows/` directory.

Copy and paste the installation snippet from the [Marketplace page](https://github.com/marketplace/actions/database-lab-migration-checker) into your .yml file.

Check out the [Database Lab DB migrations checker documentation](https://postgres.ai/docs/db-migration-checker) to learn how it works and see available configuration options

For example,

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
