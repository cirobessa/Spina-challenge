<img src="https://spinacms.com/spinacms.png" alt="Spina CMS" width="225"/>

[Spina CMS](https://spinacms.com) is an easy to use CMS that features a clean interface without distractions. [Live demo](http://spinacms-demo.herokuapp.com/admin/pages)

[![Ruby](https://github.com/SpinaCMS/Spina/actions/workflows/ruby.yml/badge.svg)](https://github.com/SpinaCMS/Spina/actions/workflows/ruby.yml)
[![Code Climate](https://codeclimate.com/github/SpinaCMS/Spina/badges/gpa.svg)](https://codeclimate.com/github/SpinaCMS/Spina)
[![Test Coverage](https://codeclimate.com/github/SpinaCMS/Spina/badges/coverage.svg)](https://codeclimate.com/github/SpinaCMS/Spina/coverage)
[![Discord](https://img.shields.io/discord/811903407525986304?label=Discord)](https://discord.gg/bv5Mu4XYcN)

## Getting Started
Start the Docker Compose build:

```
docker compose up --build -d
```

Run once the Database schema creation:
```
docker compose exec spina bundle exec rails db:create db:migrate

```

Run the installer to start the setup process:

```
    docker compose exec spina bundle exec rails g spina:install

```
The installer will help you create your first user interactively.


Then access in your Browser, using the credentials created in the last configuration step: 
   http://localhost:3000/admin


Spina is ready and running in Docker!!

There is also a folder /AWS-EKS-deploy  with instructions to deploy in AWS using EKS.
