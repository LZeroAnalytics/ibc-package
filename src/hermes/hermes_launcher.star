def generate_hermes_config(plan, chain_a_config, chain_b_config, telemetry_port, rest_port):
    config_data = {
        "TelemetryPort": telemetry_port,
        "RestPort": rest_port,
        "SourceChainID": chain_a_config["chain_id"],
        "SourceRPCURL": chain_a_config["rpc_addr"],
        "SourceGRPCURL": chain_a_config["grpc_addr"],
        "SourceAccountPrefix": chain_a_config["account_prefix"],
        "SourceMaxGas": chain_a_config["max_gas"],
        "SourceGasPrice": {
            "Amount": chain_a_config["gas_price"]["amount"],
            "Denom": chain_a_config["gas_price"]["denom"]
        },
        "PeerChainID": chain_b_config["chain_id"],
        "PeerRPCURL": chain_b_config["rpc_addr"],
        "PeerGRPCURL": chain_b_config["grpc_addr"],
        "PeerAccountPrefix": chain_b_config["account_prefix"],
        "PeerMaxGas": chain_b_config["max_gas"],
        "PeerGasPrice": {
            "Amount": chain_b_config["gas_price"]["amount"],
            "Denom": chain_b_config["gas_price"]["denom"]
        }
    }

    return plan.render_templates(
        config={
            "config.toml": struct(
                template=read_file("templates/hermes_config.tmpl"),
                data=config_data,
            )
        },
        name="hermes-config-{}-{}".format(chain_a_config["chain_id"], chain_b_config["chain_id"]),
    )

def generate_hermes_start_script(plan, chain_a_config, chain_b_config):
    script_data = {
        "ChainAID": chain_a_config["chain_id"],
        "ChainAMnemonic": chain_a_config["mnemonic"],
        "ChainAHDPath": "--hd-path \"m/44'/990'/0'/0/0\"" if chain_a_config.get("type") == "coreum" else "",
        "ChainBID": chain_b_config["chain_id"],
        "ChainBMnemonic": chain_b_config["mnemonic"],
        "ChainBHDPath": "--hd-path \"m/44'/990'/0'/0/0\"" if chain_b_config.get("type") == "coreum" else "",
    }

    return plan.render_templates(
        config={
            "hermes_start.sh": struct(
                template=read_file("templates/hermes_start.sh.tmpl"),
                data=script_data,
            )
        },
        name="hermes-start-script-{}-{}".format(chain_a_config["chain_id"], chain_b_config["chain_id"]),
    )

def start_hermes_service(plan, service_name, hermes_image, config_file, start_script_file, telemetry_port, rest_port):
    plan.add_service(
        name=service_name,
        config=ServiceConfig(
            image=hermes_image,
            files={
                "/root/.hermes/": Directory(
                    artifact_names=[config_file, start_script_file],
                ),
            },
            ports={
                "telemetry": PortSpec(number=telemetry_port, transport_protocol="TCP", wait=None),
                "rest": PortSpec(number=rest_port, transport_protocol="TCP", wait=None)
            },
            cmd=["/bin/bash", "/root/.hermes/hermes_start.sh"]
        ),
    )

def launch_hermes_participant(plan, participant):
    chain_a_config = participant["chain_a"]
    chain_b_config = participant["chain_b"]

    telemetry_port = participant["telemetry_port"]
    rest_port = participant["rest_port"]
    image = participant["image"]

    plan.print("Launching hermes for {} <-> {}".format(chain_a_config["chain_id"], chain_b_config["chain_id"]))

    service_name = "hermes-{}-{}".format(chain_a_config["chain_id"], chain_b_config["chain_id"])
    config_file = generate_hermes_config(plan, chain_a_config, chain_b_config, telemetry_port, rest_port)
    start_script_file = generate_hermes_start_script(plan, chain_a_config, chain_b_config)

    start_hermes_service(plan, service_name, image, config_file, start_script_file, telemetry_port, rest_port)

    plan.print("Hermes service started successfully for {} <-> {}".format(chain_a_config["chain_id"], chain_b_config["chain_id"]))

def launch_hermes(plan, participants):
    for participant in participants:
        launch_hermes_participant(plan, participant)