# Agent handoff

## 2026-11-26 development phase

The active local branch is `feature/4g-control-payload`, based on the keyboard branch. It targets PX4 **1.16.0** and adds `FlightControlSourcePanel.qml`, `PayloadControlPanel.qml`, a read-only failsafe check, `Vehicle::sendPayloadActuator()`, and `ParameterManager::parameterValueReceived`. Read `docs/agent-handoff/REMOTE_CONTROL_2026_11_26.md` and `docs/4G_REMOTE_CONTROL_TEST_REPORT.md` before further edits. The user authorized upload of this development branch on 2026-11-27; do not force-push or replace the diverged `main` branch. The Windows Release executable builds and starts, but RC/4G switching, actuator ACK, PX4 SITL, HyperLTE and real RC behavior have **not** passed end-to-end testing. The 2026-11-27 full Debug unit suite failed and crashed; see the test report.

PX4 1.16 `COM_RC_IN_MODE=0/1` permits explicit parameter selection while both inputs are healthy, but mode 1 disables RC. If the 4G connection fails, QGC cannot switch back over the lost link; do not describe the still-connected SBUS receiver as a usable backup in this mode. The panel verifies parameter readback, not PX4's active `manual_control_setpoint.data_source`. The 4G failsafe panel does not modify failsafe parameters or detect HyperLTE-only loss when another GCS heartbeat persists. Current-airframe hardware settings remain unknown. Do not test on a real aircraft before SITL and propeller-free bench validation.
The source-switch buttons are deliberately limited to the disarmed state until SITL and bench handoff tests are complete.

The older notes below describe the preceding PX4 1.13.3 research and keyboard-only stage; use the new 1.16 documents for this branch.

This is QGroundControl v4.4.5 with the Windows Keyboard Joystick panel on branch `feature/keyboard-joystick`. The panel is in `src/FlightDisplay/KeyboardJoystickPanel.qml` and is mounted from `FlyView.qml`. It sends MAVLink `MANUAL_CONTROL` through the existing Vehicle joystick path, not Offboard velocity commands.

Build and tests: see `docs/agent-handoff/README.md` and `TEST_REPORT.md`. Local Windows build: `D:\ROS2Android\QGC_modification\build-QGC4.4.5\staging\QGroundControl.exe`. The build directory and executable are local, not in Git. Tests used a local fake MAVLink endpoint; no real PX4 1.13.3 / HyperLTE / G20 combined control test has passed.

4G architecture and limitations: see `docs/agent-handoff/HYPERLTE_4G_CHAIN_REVIEW.md` and `docs/4G_MANUAL_CONTROL_DESIGN.md`. PX4 1.13.3 `COM_RC_IN_MODE=2` switches only after the current source becomes invalid; it does not provide operator-selected switching while RC and MAVLink inputs are both healthy. Do not claim the QGC panel implements RC/4G arbitration. The user prefers explicit operator selection and no automatic RC preemption; fulfilling simultaneous-source switching needs a flight-controller-side arbitration mechanism or an equivalent verified onboard gateway.

The current aircraft is a different airframe with changed parameters. Read its actual `SER_TEL1_BAUD`, `MAV_0_CONFIG`, `COM_RC_IN_MODE`, and failsafe settings; do not apply values from the earlier report. The HyperLTE manual and extracted copies contain network and default camera credentials and are intentionally excluded from this public repository. Do not publish those files or actual endpoint credentials. Keep the upstream QGC source license and submodule references; clone with `git clone --recurse-submodules`.
