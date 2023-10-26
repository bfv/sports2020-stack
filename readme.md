# Sports2020 Docker Compose stack

## install
- Use the CLI
- go to c:/temp
- `git clone https://github.com/bfv/sports2020-stack`
- copy your own `progress.cfg` file to `c:/temp/sports2020-stack`

Optionally:
- set the `PORT` in the `.env` file
- set the `DOMAIN` in the `.env` file

# running the stack
- in de workdir: `docker compose up --scale backend=3 -d`
