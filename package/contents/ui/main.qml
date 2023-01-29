/*
 * Copyright 2016  Daniel Faust <hessijames@gmail.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http: //www.gnu.org/licenses/>.
 */
import QtQuick 2.2
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore

Item {
    property bool showSeparately: plasmoid.configuration.showSeparately
    property string speedLayout: plasmoid.configuration.speedLayout
    property bool swapDownUp: plasmoid.configuration.swapDownUp
    property bool showIcons: plasmoid.configuration.showIcons
    property bool showUnits: plasmoid.configuration.showUnits
    property string speedUnits: plasmoid.configuration.speedUnits
    property bool shortUnits: plasmoid.configuration.shortUnits
    property double fontSizeScale: plasmoid.configuration.fontSize / 100
    property double updateInterval: plasmoid.configuration.updateInterval
    property bool customColors: plasmoid.configuration.customColors
    property color byteColor: plasmoid.configuration.byteColor
    property color kilobyteColor: plasmoid.configuration.kilobyteColor
    property color megabyteColor: plasmoid.configuration.megabyteColor
    property color gigabyteColor: plasmoid.configuration.gigabyteColor

    property bool launchApplicationEnabled: plasmoid.configuration.launchApplicationEnabled
    property string launchApplication: plasmoid.configuration.launchApplication
    property bool interfacesWhitelistEnabled: plasmoid.configuration.interfacesWhitelistEnabled
    property var interfacesWhitelist: plasmoid.configuration.interfacesWhitelist

    property var speedData: []

    Plasmoid.preferredRepresentation: Plasmoid.compactRepresentation
    Plasmoid.compactRepresentation: CompactRepresentation {}

    Component.onCompleted: {
        // trigger adding all sources already available
        netSource.fetchSources()
    }

    Connections {
        target: netSource
        onExited: {
            var interfaces = stdout.trim().split('\n')
            for (var netInt of interfaces) {
                if(netInt === 'lo' || speedData[netInt] !== undefined) {
                    continue
                }

                trafficSource.sources(netInt)

                console.log('Network interface added: ', netInt)
            }
        }
    }

    PlasmaCore.DataSource {
        id: netSource
        engine: 'executable'
        interval: updateInterval * 1000
        onNewData: (sourceName, data) => {
            var exitCode = data['exit code']
            var exitStatus = data['exit status']
            var stdout = data['stdout']
            var stderr = data['stderr']
            exited(exitCode, exitStatus, stdout, stderr)
        }
        function fetchSources() {
            connectSource('ls -1 /sys/class/net')
        }
        signal exited(int exitCode, int exitStatus, string stdout, string stderr)
    }

    PlasmaCore.DataSource {
        id: trafficSource
        engine: 'executable'
        interval: updateInterval * 1000
        onNewData: (sourceName, data) => {
            var exitCode = data['exit code']
            var exitStatus = data['exit status']
            var stdout = data['stdout'].trim()
            var stderr = data['stderr']
            var bytes = [0,0]

            if (stdout !== '') {
                // [0] = upload, [1] = download
                bytes = stdout.trim().split('\n').map(val => parseFloat(val) / 1024)
            }

            var match = sourceName.match(/^cat \/sys\/class\/net\/(.+?)\/statistics\/.*/)
            
            // Unlikely, but just in case
            if (match === null) {
                return
            }

            var interfaceId = match[1]

            if (typeof speedData[interfaceId] === 'undefined') {
                speedData[interfaceId] = {down: 0, up: 0, downTotal: 0, upTotal: 0}
            }

            var d = speedData
            
            // Download rate values
            d[interfaceId].down = (bytes[1] - d[interfaceId].downTotal)
            d[interfaceId].downTotal = bytes[1]
            
            // Upload rate values
            d[interfaceId].up = (bytes[0] - d[interfaceId].upTotal)
            d[interfaceId].upTotal = bytes[0]
            
            speedData = d
            

            exited(exitCode, exitStatus, stdout, stderr)
        }
        function sources(i) {
            connectSource(`cat /sys/class/net/${i}/statistics/tx_bytes /sys/class/net/${i}/statistics/rx_bytes`)
        }
        signal exited(int exitCode, int exitStatus, string stdout, string stderr)
    }
}
