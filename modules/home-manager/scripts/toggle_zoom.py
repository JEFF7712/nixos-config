#! /home/rupan/.local/share/fx-automation/bin/python
from marionette_driver.marionette import Marionette

client = Marionette(host='localhost', port=2828)
client.start_session()

with client.using_context("chrome"):
    current_val = client.execute_script("""
        return Services.prefs.getCharPref('layout.css.devPixelsPerPx', '-1.0');
    """)

    new_val = "2.0" if current_val == "1.0" else "1.0"
    
    client.execute_script(f"""
        Services.prefs.setCharPref('layout.css.devPixelsPerPx', '{new_val}');
    """)

client.delete_session()
