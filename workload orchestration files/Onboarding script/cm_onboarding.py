import sys
import json
from typing import List

from azure.cli.core import get_default_cli


class RBAC(object):
    def __init__(self, role: str, userGroup: str):
        self.role = role
        self.userGroup = userGroup

class Target(object):
    def __init__(self, name: str,
                 customLocation: str,
                 displayName: str,
                 capabilities: List[str] = None,
                 hierarchyLevel: str = None,
                 rbac: RBAC = None,
                 namespace: str = None):
        self.name = name
        self.capabilities = capabilities
        self.hierarchyLevel = hierarchyLevel
        self.customLocation = customLocation
        self.displayName = displayName
        self.rbac = rbac
        self.namespace = namespace

class DeploymentTarget(object):
    def __init__(self,
                 targets: List[Target],
                 capabilities: List[str] = None,
                 hierarchyLevel: str = None,
                 rbac: RBAC = None,
                 namespace: str = None,
                 customLocation: str = None):
        self.rbac = rbac
        self.targets = targets
        self.capabilities = capabilities
        self.hierarchyLevel = hierarchyLevel
        self.namespace = namespace
        self.customLocation = customLocation

class CapabilityList(object):
    def __init__(self, name, capabilities: List[str]):
        self.capabilities = capabilities
        self.name = name
class HierarchyLevels(object):
    def __init__(self, name, levels: List[str]):
        self.levels = levels
        self.name = name

class Onboarding(object):
    def __init__(self,
                 resourceGroup: str,
                 subscriptionId: str,
                 location: str,
                 deploymentTargets: List[DeploymentTarget],
                 capabilityList: CapabilityList = None,
                 hierarchyList: HierarchyLevels = None,
                 namespace: str = None):
        self.resourceGroup = resourceGroup
        self.subscriptionId = subscriptionId
        self.deploymentTargets = deploymentTargets
        self.location = location
        self.capabilityList = capabilityList
        self.hierarchyLevels = hierarchyList
        self.namespace = namespace

onboarding_file = sys.argv[1]
data = ""
with open(onboarding_file, "r+") as file:
    data = file.read()

input = Onboarding(**json.loads(data))

if input.capabilityList is not None:
    cli = get_default_cli()
    cli.invoke(["config-manager",
                "capabilities",
                "create",
                "-n",
                input.capabilityList["name"],
                "--capabilities",
                ",".join(input.capabilityList["capabilities"]),
                "-g",
                input.resourceGroup,
                "--subscription",
                input.subscriptionId,
                "-l",
                input.location])
    if cli.result.error is not None:
        exit(0)
if input.hierarchyLevels is not None:
    cli = get_default_cli()
    cli.invoke(["config-manager",
                "hierarchies",
                "create",
                "-n",
                input.hierarchyLevels["name"],
                "--levels",
                ",".join(input.hierarchyLevels["levels"]),
                "-g",
                input.resourceGroup,
                "--subscription",
                input.subscriptionId,
                "-l",
                input.location])
    if cli.result.error is not None:
        exit(0)
for dt in input.deploymentTargets["targets"]:
    cli = get_default_cli()
    if "capabilities" not in dt and "capabilities" in input.deploymentTargets:
        dt["capabilities"] = input.deploymentTargets["capabilities"]
    if "hierarchyLevel" not in dt and "hierarchyLevel" in input.deploymentTargets:
        dt["hierarchyLevel"] = input.deploymentTargets["hierarchyLevel"]
    if "rbac" not in dt and "rbac" in input.deploymentTargets:
        dt["rbac"] = input.deploymentTargets["rbac"]
    if "customLocation" not in dt and "customLocation" in input.deploymentTargets:
        dt["customLocation"] = input.deploymentTargets["customLocation"]
    if "namespace" not in dt and "namespace" in input.deploymentTargets:
        dt["namespace"] = input.deploymentTargets["namespace"]
    args = ["config-manager",
                    "deployment-target",
                    "create",
                    "-n", dt["name"],
                    "--display-name",
                    dt["displayName"],
                    "--capabilities",
                    ",".join(dt["capabilities"]),
                    "--hierarchy-level",
                    dt["hierarchyLevel"],
                    "--custom-location",
                    dt["customLocation"],
                    "-g",
                    input.resourceGroup,
                    "--subscription",
                    input.subscriptionId,
                    "-l",
                    input.location]
    if "namespace" in dt:
        args.append("--scope")
        args.append(dt["namespace"])
    cli.invoke(args)
    if cli.result.error is None and cli.result.result is not None and "rbac" in dt:
        id = cli.result.result["id"]
        rbac_cli = get_default_cli()
        rbac_cli.invoke(["role", "assignment","create", "--assignee", dt["rbac"]["userGroup"],"--role", dt["rbac"]["role"], "--scope", id])
        if rbac_cli.result.error is not None:
            exit(0)