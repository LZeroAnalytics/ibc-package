hermes = import_module("./src/hermes/hermes_launcher.star")

def run(plan, args):
    hermes.launch_hermes(plan, args["participants"])