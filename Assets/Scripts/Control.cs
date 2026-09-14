using UnityEngine;
using UnityEngine.Serialization;

public class Control : MonoBehaviour
{
    [SerializeField] private GameObject[] GameObjects;

    [Tooltip("拖拽灵敏度(度/像素)")]
    [SerializeField] private float RotateSpeed = 0.3f;

    private Vector2 _lastMousePos;
    private Camera _mainCamera;

    void Start()
    {
        _mainCamera = Camera.main;
    }

    void Update()
    {
        Vector2 delta = ReadDragDelta();
        if (delta.sqrMagnitude > 0f)
            RotateAll(delta);
    }

    private Vector2 ReadDragDelta()
    {
        if (Input.touchCount > 0)
        {
            Touch touch = Input.GetTouch(0);
            return touch.phase == TouchPhase.Moved ? touch.deltaPosition : Vector2.zero;
        }

        if (Input.GetMouseButtonDown(0))
            _lastMousePos = Input.mousePosition;

        if (Input.GetMouseButton(0))
        {
            Vector2 delta = (Vector2)Input.mousePosition - _lastMousePos;
            _lastMousePos = Input.mousePosition;
            return delta;
        }

        return Vector2.zero;
    }

    private void RotateAll(Vector2 delta)
    {
        Vector3 pitchAxis = _mainCamera.transform.right;

        foreach (GameObject go in GameObjects)
        {
            if (!go) continue;

            Transform t = go.transform;
            t.Rotate(Vector3.up, -delta.x * RotateSpeed, Space.World);
            t.Rotate(pitchAxis, delta.y * RotateSpeed, Space.World);
        }
    }
}
