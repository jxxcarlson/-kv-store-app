# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A key-value store application with a Haskell/Postgres backend and Elm frontend. See `spec.md` for the full specification.

## Architecture

- **Backend**: Haskell + PostgreSQL
- **Frontend**: Elm
- **Data model**: Three tables — Data (key-value entries with metadata), User, Group (with read/write permissions)

## Key Concepts

- Data entries have an owner (User FK) and group (Group FK), with group-based access control (read/write booleans)
- There is a special "public" group (owner 0) that grants read access to anyone
- Authenticated users can create docs and groups and become their owner
- Only a doc's owner can assign it to a group
