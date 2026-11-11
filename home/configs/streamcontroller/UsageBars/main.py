from src.backend.DeckManagement.InputIdentifier import Input
from src.backend.PluginManager.ActionHolder import ActionHolder
from src.backend.PluginManager.ActionInputSupport import ActionInputSupport
from src.backend.PluginManager.PluginBase import PluginBase

from .actions.UsageBar import UsageBar
from .usage import UsageData


class UsageBarsPlugin(PluginBase):
    def __init__(self):
        super().__init__()

        self.usage = UsageData()

        self.add_action_holder(
            ActionHolder(
                plugin_base=self,
                action_base=UsageBar,
                action_id_suffix="UsageBar",
                action_name="Usage Bar",
                action_support={
                    Input.Key: ActionInputSupport.SUPPORTED,
                    Input.Dial: ActionInputSupport.UNSUPPORTED,
                    Input.Touchscreen: ActionInputSupport.UNSUPPORTED,
                },
            )
        )

        self.register(
            plugin_name="Usage Bars",
            github_repo="https://github.com/JEFF7712/nixos",
            plugin_version="1.0.0",
            app_version="1.5.0-beta",
        )
