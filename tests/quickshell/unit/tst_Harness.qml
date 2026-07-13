import QtQuick
import QtTest

TestCase {
    name: "QuickshellHarness"

    Component {
        id: objectComponent

        QtObject {
            property int value: 1
        }
    }

    function test_propertyChangeSignal() {
        const object = createTemporaryObject(objectComponent, this);
        verify(object !== null);

        let changes = 0;
        object.valueChanged.connect(() => changes++);
        object.value = 2;

        compare(object.value, 2);
        compare(changes, 1);
    }
}
