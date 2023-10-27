# Sports2020 Docker Compose stack

## install
- Use the CLI
- go to c:/temp
- `git clone https://github.com/bfv/sports2020-stack`
- copy your own `progress.cfg` file to `c:/temp/sports2020-stack`
- make a entry in your `hosts` file for the `sports2020.bfv.io` to `127.0.0.1` or whatever domain you want to use

## modify the defaults
Check the `.env` when you want to change any of the following:
- the hostname the stack listens to (in `DOMAIN`)
- the port the stack listen to (in `PORT`)
- the location of the `progress.cfg` file
  
# running the stack
- in de workdir: `docker compose up --scale backend=3 -d`
