# Agent handoff

This is QGroundControl v4.4.5 with the Windows Keyboard Joystick panel on branch `feature/keyboard-joystick`. The panel is in `src/FlightDisplay/KeyboardJoystickPanel.qml` and is mounted from `FlyView.qml`. It sends MAVLink `MANUAL_CONTROL` through the existing Vehicle joystick path, not Offboard velocity commands.

Build and tests: see `docs/agent-handoff/README.md` and `TEST_REPORT.md`. Local Windows build: `D:\ROS2Android\QGC_modification\build-QGC4.4.5\staging\QGroundControl.exe`. The build directory and executable are local, not in Git. Tests used a local fake MAVLink endpoint; no real PX4 1.13.3 / HyperLTE / G20 combined control test has passed.

4G architecture and limitations: see `docs/agent-handoff/HYPERLTE_4G_CHAIN_REVIEW.md` and `docs/4G_MANUAL_CONTROL_DESIGN.md`. PX4 1.13.3 `COM_RC_IN_MODE=2` switches only after the current source becomes invalid; it does not provide operator-selected switching while RC and MAVLink inputs are both healthy. Do not claim the QGC panel implements RC/4G arbitration. The user prefers explicit operator selection and no automatic RC preemption; fulfilling simultaneous-source switching needs a flight-controller-side arbitration mechanism or an equivalent verified onboard gateway.

The current aircraft is a different airframe with changed parameters. Read its actual `SER_TEL1_BAUD`, `MAV_0_CONFIG`, `COM_RC_IN_MODE`, and failsafe settings; do not apply values from the earlier report. The HyperLTE manual and extracted copies contain network and default camera credentials and are intentionally excluded from this public repository. Do not publish those files or actual endpoint credentials. Keep the upstream QGC source license and submodule references; clone with `git clone --recurse-submodules`.
