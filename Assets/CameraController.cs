using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraController : MonoBehaviour
{
    public enum RenderMode { Normal, OIT }

    public Vector3 m_lookAt = new Vector3(0, 1, -10);
    public float m_speed = 10;
    public Shader m_listCreationShader = null;
    public Shader m_listBlendingShader = null;
    public Camera m_transparentCamera = null;
    public RenderMode m_renderMode = RenderMode.OIT;
    public int m_size = 3;

    private Camera m_camera;

    private struct ListNode
    {
        public Vector4 pixelColor;
        public float depth;
        public uint next;
    }

    private ComputeBuffer m_listNodeBuffer;
    private ComputeBuffer m_listHeadBuffer;
    private uint[] m_listHeadBufferResetTable;
    private Material m_blendMaterial;

    // Start is called before the first frame update
    void Start()
    {
        m_camera = GetComponent<Camera>();
        m_blendMaterial = new Material(m_listBlendingShader);

        int m_bufferSize = Screen.width * Screen.height * m_size;
        int m_bufferStride = sizeof(float) * 5 + sizeof(uint);
        m_listNodeBuffer = new ComputeBuffer(m_bufferSize, m_bufferStride, ComputeBufferType.Counter);

        m_bufferSize = Screen.width * Screen.height;
        m_bufferStride = sizeof(uint);
        m_listHeadBuffer = new ComputeBuffer(m_bufferSize, m_bufferStride, ComputeBufferType.Raw);

        m_listHeadBufferResetTable = new uint[m_bufferSize];
        foreach (int i in m_listHeadBufferResetTable)
        {
            m_listHeadBufferResetTable[i] = 0;
        }
    }

    // Update is called once per frame
    void Update()
    {
        transform.RotateAround(m_lookAt, Vector3.up, m_speed * Time.deltaTime);
        transform.LookAt(m_lookAt);
    }

    void OnPreRender()
    {
        if (m_renderMode == RenderMode.OIT)
        {
            m_camera.cullingMask = ~(1 << LayerMask.NameToLayer("Transparent"));
            m_transparentCamera.cullingMask = 1 << LayerMask.NameToLayer("Transparent");
        }
        else
        {
            m_camera.cullingMask = -1;
            m_transparentCamera.cullingMask = 0;
        }
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (m_renderMode == RenderMode.OIT)
        {
            m_listHeadBuffer.SetData(m_listHeadBufferResetTable);
            m_listNodeBuffer.SetCounterValue(1);
            Graphics.SetRandomWriteTarget(1, m_listNodeBuffer, true);
            Graphics.SetRandomWriteTarget(2, m_listHeadBuffer);
            m_transparentCamera.targetTexture = source;
            m_transparentCamera.RenderWithShader(m_listCreationShader, null);
            Graphics.ClearRandomWriteTargets();
            m_blendMaterial.SetBuffer("ListNodeBuffer", m_listNodeBuffer);
            m_blendMaterial.SetBuffer("ListHeadBuffer", m_listHeadBuffer);
            Graphics.Blit(source, destination, m_blendMaterial);
        }
        else
        {
            Graphics.Blit(source, destination);
        }
    }

    void OnDestroy()
    {
        m_listNodeBuffer.Release();
        m_listHeadBuffer.Release();
    }
}
