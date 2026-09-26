# Example: Autobahn Testsuite in Solar2D

Runs the [Autobahn|Testsuite](https://github.com/crossbario/autobahn-testsuite) conformance cases against dmc-websockets inside a Solar2D app. The screen shows the current case, a progress bar and a running tally of results; the console logs each case.

<p>
<img src="images/autobahn-running.png" width="320" alt="The example mid-run: 166 of 301 cases, case 6.21.6, 163 OK and 2 non-strict so far">
<img src="images/autobahn-complete.png" width="320" alt="The finished run: 301 of 301 cases, 296 OK, 2 non-strict, 3 informational, 0 failed, with the cases that weren't OK listed">
</p>

The progress bar is green while every case is OK and turns yellow after a non-strict result (red after a failure), so its colour shows the worst result so far.

To run the same suite without Solar2D, from the command line, see [Development](../../docs/development.md#autobahn-testsuite).

## Run It

Prerequisites: Docker and the Solar2D Simulator.

1. **Start the fuzzing server** from the repository root:

   ```sh
   tests/autobahn/server.sh start
   ```

   The first start takes a minute or two (the image is x86-only and runs under emulation on Apple Silicon). It ends with `fuzzingserver listening on ws://127.0.0.1:9001`.

2. **Open this folder in the Solar2D Simulator** (File > Open, choose `main.lua`). The suite starts right away; all 301 cases take about 10 minutes (each case uses three short connections: its description, the case itself and its result). The Simulator restarts the run if a file in this folder changes while it runs. When it finishes, the screen shows `Complete` and lists any case that wasn't OK, and the console ends with:

   ```text
   Complete: 301 cases in 9:10
     OK             296
     NON-STRICT     2
     INFORMATIONAL  3
   Reports updated for agent dmc_websockets_solar2d
   ```

   If the screen says `No fuzzing server`, step 1 isn't running or `app_config.lua` points at another address.

3. **Read the reports** at `tests/autobahn/reports/solar2d/clients/index.html`, one page per case. Compare them with the headless results using `python3 tests/autobahn/summarize.py tests/autobahn/reports/after tests/autobahn/reports/solar2d`.

4. **Stop the server:** `tests/autobahn/server.sh stop`.

## Settings

`app_config.lua`:

| Setting | Default | Description |
|---|---|---|
| `host`, `port` | `127.0.0.1`, `9001` | Where the fuzzing server runs. To test from a phone, use the LAN address of the computer running Docker |
| `agent` | `dmc_websockets_solar2d` | Name the results are filed under in the reports |
| `cases` | `nil` (all) | Only run these cases, e.g. `{ '1.1.1', '6.4.3', '9.1.3' }` |
| `case_timeout` | `60` | Seconds before a case that hangs is abandoned |

The results are explained on the [compliance page](../../docs/compliance.md).
