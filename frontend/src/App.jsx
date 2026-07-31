import React, { useState, useEffect } from 'react';
import './App.css';

const API_BASE = import.meta.env.VITE_API_BASE_URL || '';

function App() {
  // State variables
  const [name, setName] = useState('');
  const [namesList, setNamesList] = useState([]);
  const [file, setFile] = useState(null);
  const [filesList, setFilesList] = useState([]);
  const [healthStatus, setHealthStatus] = useState(null);
  
  // Loading & Error States
  const [isSubmittingName, setIsSubmittingName] = useState(false);
  const [isUploadingFile, setIsUploadingFile] = useState(false);
  const [nameError, setNameError] = useState('');
  const [fileError, setFileError] = useState('');
  const [isLoadingNames, setIsLoadingNames] = useState(false);
  const [isLoadingFiles, setIsLoadingFiles] = useState(false);

  // Fetch initial data
  useEffect(() => {
    fetchHealthStatus();
    fetchNames();
    fetchFiles();
  }, []);

  const fetchHealthStatus = async () => {
    try {
      const res = await fetch(`${API_BASE}/api/health`);
      if (res.ok) {
        const data = await res.json();
        setHealthStatus(data);
      } else {
        setHealthStatus({ status: 'unhealthy', error: 'HTTP status ' + res.status });
      }
    } catch (err) {
      setHealthStatus({ status: 'unreachable', error: err.message });
    }
  };

  const fetchNames = async () => {
    setIsLoadingNames(true);
    try {
      const res = await fetch(`${API_BASE}/api/names`);
      if (res.ok) {
        const data = await res.json();
        setNamesList(data);
      }
    } catch (err) {
      console.error('Error fetching names:', err);
    } finally {
      setIsLoadingNames(false);
    }
  };

  const fetchFiles = async () => {
    setIsLoadingFiles(true);
    try {
      const res = await fetch(`${API_BASE}/api/files`);
      if (res.ok) {
        const data = await res.json();
        setFilesList(data);
      }
    } catch (err) {
      console.error('Error fetching files:', err);
    } finally {
      setIsLoadingFiles(false);
    }
  };

  // Submit Name (API 1)
  const handleNameSubmit = async (e) => {
    e.preventDefault();
    if (!name.trim()) {
      setNameError('Name cannot be empty');
      return;
    }
    setNameError('');
    setIsSubmittingName(true);

    try {
      const res = await fetch(`${API_BASE}/api/names`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: name.trim() })
      });

      if (res.ok) {
        setName('');
        fetchNames();
        fetchHealthStatus(); // Refresh status
      } else {
        const errData = await res.json();
        setNameError(errData.error || 'Failed to submit name');
      }
    } catch (err) {
      setNameError('Network error: ' + err.message);
    } finally {
      setIsSubmittingName(false);
    }
  };

  // Submit File (API 2)
  const handleFileSubmit = async (e) => {
    e.preventDefault();
    if (!file) {
      setFileError('Please select a file to upload');
      return;
    }
    setFileError('');
    setIsUploadingFile(true);

    const formData = new FormData();
    formData.append('file', file);

    try {
      const res = await fetch(`${API_BASE}/api/files`, {
        method: 'POST',
        body: formData
      });

      if (res.ok) {
        setFile(null);
        // Reset file input element
        document.getElementById('file-input').value = '';
        fetchFiles();
        fetchHealthStatus(); // Refresh status
      } else {
        const errData = await res.json();
        setFileError(errData.error || 'Failed to upload file');
      }
    } catch (err) {
      setFileError('Network error: ' + err.message);
    } finally {
      setIsUploadingFile(false);
    }
  };

  const getStatusBadge = () => {
    if (!healthStatus) return <span className="badge loading">Loading Diagnostic...</span>;
    if (healthStatus.status === 'healthy') {
      return <span className="badge healthy">Active Cluster (Healthy)</span>;
    }
    return <span className="badge unhealthy">Degraded (Check Logs)</span>;
  };

  return (
    <div className="container">
      {/* Header / Top Navigation */}
      <header className="app-header">
        <div className="logo-section">
          <div className="logo-icon"></div>
          <div>
            <h1>EKS Cluster Demo</h1>
            <p className="subtitle">Microservices Architecture Showcase</p>
          </div>
        </div>
        <div className="status-container">
          {getStatusBadge()}
        </div>
      </header>

      {/* Hero Stats */}
      <section className="stats-grid">
        <div className="stat-card">
          <h3>EKS Deployment Node</h3>
          <p className="stat-value">Karpenter</p>
          <p className="stat-desc">Autoscaled Node pool</p>
        </div>
        <div className="stat-card">
          <h3>Database (Atlas)</h3>
          <p className={`stat-value ${healthStatus?.mongodb === 'connected' ? 'connected' : 'disconnected'}`}>
            {healthStatus?.mongodb === 'connected' ? 'Connected' : 'Disconnected'}
          </p>
          <p className="stat-desc">VPC Peered Connection</p>
        </div>
        <div className="stat-card">
          <h3>Storage (S3)</h3>
          <p className={`stat-value ${healthStatus?.s3Bucket === 'configured' ? 'connected' : 'disconnected'}`}>
            {healthStatus?.s3Bucket === 'configured' ? 'Active' : 'Unconfigured'}
          </p>
          <p className="stat-desc">Private Gateway Endpoint</p>
        </div>
      </section>

      {/* Main Dashboard Layout */}
      <main className="dashboard-grid">
        {/* Left Side: API 1 - Names in MongoDB Atlas */}
        <section className="dashboard-card glass">
          <div className="card-header">
            <div className="icon mongo-icon"></div>
            <h2>MongoDB Atlas Service</h2>
            <span className="api-badge">API 1</span>
          </div>
          <p className="card-description">
            Submits raw input payloads to a Node.js backend which writes persistent documents to a MongoDB Atlas cluster over a peered VPC link.
          </p>

          <form onSubmit={handleNameSubmit} className="interactive-form">
            <div className="input-group">
              <input
                type="text"
                placeholder="Enter a name to save..."
                value={name}
                onChange={(e) => setName(e.target.value)}
                disabled={isSubmittingName}
              />
              <button type="submit" className="btn btn-primary" disabled={isSubmittingName}>
                {isSubmittingName ? 'Saving...' : 'Store Name'}
              </button>
            </div>
            {nameError && <p className="error-text">{nameError}</p>}
          </form>

          <div className="data-list-container">
            <h3>Stored Records</h3>
            {isLoadingNames ? (
              <div className="list-loading">Loading records...</div>
            ) : namesList.length === 0 ? (
              <div className="list-empty">No records stored yet.</div>
            ) : (
              <ul className="data-list">
                {namesList.map((item) => (
                  <li key={item._id} className="data-item">
                    <span className="item-text">{item.name}</span>
                    <span className="item-meta">{new Date(item.createdAt).toLocaleTimeString()}</span>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </section>

        {/* Right Side: API 2 - Files in S3 via Endpoint */}
        <section className="dashboard-card glass">
          <div className="card-header">
            <div className="icon s3-icon"></div>
            <h2>AWS S3 Storage Service</h2>
            <span className="api-badge">API 2</span>
          </div>
          <p className="card-description">
            Uploads local media assets and files directly to a secure S3 bucket via private S3 VPC Gateway Endpoints, avoiding public internet routing.
          </p>

          <form onSubmit={handleFileSubmit} className="interactive-form">
            <div className="file-upload-wrapper">
              <input
                id="file-input"
                type="file"
                onChange={(e) => setFile(e.target.files[0])}
                disabled={isUploadingFile}
              />
              <div className="custom-file-indicator">
                {file ? `Selected: ${file.name}` : 'Drag & drop or click to choose file'}
              </div>
              <button type="submit" className="btn btn-secondary" disabled={isUploadingFile || !file}>
                {isUploadingFile ? 'Uploading...' : 'Upload File'}
              </button>
            </div>
            {fileError && <p className="error-text">{fileError}</p>}
          </form>

          <div className="data-list-container">
            <h3>Uploaded Objects</h3>
            {isLoadingFiles ? (
              <div className="list-loading">Loading metadata...</div>
            ) : filesList.length === 0 ? (
              <div className="list-empty">No objects uploaded yet.</div>
            ) : (
              <ul className="data-list">
                {filesList.map((item) => (
                  <li key={item._id || item.s3Key} className="data-item file-item">
                    <div className="file-info">
                      <span className="item-text filename">{item.originalName}</span>
                      <span className="item-meta">{new Date(item.createdAt).toLocaleDateString()}</span>
                    </div>
                    <a
                      href={item.s3Url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="download-link"
                    >
                      Open Link
                    </a>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </section>
      </main>

      {/* Infrastructure Insights */}
      <footer className="dashboard-footer">
        <p>Managed via <strong>ArgoCD (GitOps)</strong>. Node Autoscaling by <strong>Karpenter</strong>.</p>
        <p className="copyright">&copy; {new Date().getFullYear()} EKS Cloud Task Demo</p>
      </footer>
    </div>
  );
}

export default App;
