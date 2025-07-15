class TalentPlatform {
    constructor() {
        this.contractAddress = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.dec-talent-platform';
        this.projects = [];
        this.artists = [];
        this.currentUser = null;
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.loadData();
        this.checkWalletConnection();
    }

    setupEventListeners() {
        document.getElementById('connectWallet').addEventListener('click', () => this.connectWallet());
        document.getElementById('createProjectBtn').addEventListener('click', () => this.showCreateProjectModal());
        document.getElementById('closeModal').addEventListener('click', () => this.hideModal('createProjectModal'));
        document.getElementById('cancelProject').addEventListener('click', () => this.hideModal('createProjectModal'));
        document.getElementById('createProjectForm').addEventListener('submit', (e) => this.handleCreateProject(e));
        document.getElementById('closeProjectModal').addEventListener('click', () => this.hideModal('projectModal'));
        document.getElementById('closeArtistModal').addEventListener('click', () => this.hideModal('artistModal'));
        document.getElementById('cancelArtist').addEventListener('click', () => this.hideModal('artistModal'));
        document.getElementById('artistProfileForm').addEventListener('submit', (e) => this.handleCreateArtistProfile(e));
        document.getElementById('statusFilter').addEventListener('change', () => this.filterProjects());
        document.getElementById('searchProjects').addEventListener('input', () => this.filterProjects());
        document.getElementById('toastClose').addEventListener('click', () => this.hideToast());

        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('modal')) {
                this.hideModal(e.target.id);
            }
        });
    }

    async checkWalletConnection() {
        if (window.StacksProvider) {
            try {
                const userData = await window.StacksProvider.getUser();
                if (userData && userData.profile) {
                    this.currentUser = userData.profile.stxAddress.mainnet;
                    this.updateWalletUI();
                }
            } catch (error) {
                console.log('No wallet connected');
            }
        }
    }

    async connectWallet() {
        if (!window.StacksProvider) {
            this.showToast('Please install Hiro Wallet or Xverse', 'error');
            return;
        }

        try {
            this.showLoading();
            const userData = await window.StacksProvider.authenticate();
            this.currentUser = userData.profile.stxAddress.mainnet;
            this.updateWalletUI();
            this.showToast('Wallet connected successfully!', 'success');
        } catch (error) {
            this.showToast('Failed to connect wallet', 'error');
        } finally {
            this.hideLoading();
        }
    }

    updateWalletUI() {
        const connectBtn = document.getElementById('connectWallet');
        const walletAddress = document.getElementById('walletAddress');
        
        if (this.currentUser) {
            connectBtn.style.display = 'none';
            walletAddress.textContent = `${this.currentUser.slice(0, 6)}...${this.currentUser.slice(-4)}`;
            walletAddress.style.display = 'block';
        } else {
            connectBtn.style.display = 'block';
            walletAddress.style.display = 'none';
        }
    }

    loadData() {
        this.projects = this.generateMockProjects();
        this.artists = this.generateMockArtists();
        this.renderProjects();
        this.renderArtists();
    }

    generateMockProjects() {
        return [
            {
                id: 1,
                title: "Digital Art Collection NFT",
                description: "Creating a unique collection of digital art pieces exploring themes of nature and technology. Each piece will be hand-crafted using digital painting techniques.",
                artist: "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
                fundingGoal: 1000,
                currentFunding: 750,
                votes: 23,
                status: "active",
                deadline: Date.now() + 7 * 24 * 60 * 60 * 1000,
                collaborationOpen: true
            },
            {
                id: 2,
                title: "Interactive Music Visualizer",
                description: "Building an innovative music visualizer that responds to audio input with stunning geometric patterns and color schemes.",
                artist: "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG",
                fundingGoal: 1500,
                currentFunding: 1500,
                votes: 35,
                status: "completed",
                deadline: Date.now() - 2 * 24 * 60 * 60 * 1000,
                collaborationOpen: false
            },
            {
                id: 3,
                title: "Street Photography Book",
                description: "Documenting urban life through candid street photography. The book will feature 100+ photos from cities around the world.",
                artist: "ST3AM1A56AK2C1XAFJ4115ZSV26EB49BVQ10MGCS0",
                fundingGoal: 800,
                currentFunding: 320,
                votes: 12,
                status: "active",
                deadline: Date.now() + 14 * 24 * 60 * 60 * 1000,
                collaborationOpen: true
            }
        ];
    }

    generateMockArtists() {
        return [
            {
                address: "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
                name: "Alex Digital",
                bio: "Digital artist specializing in NFT collections and blockchain art",
                portfolioUrl: "https://alexdigital.art",
                reputationScore: 450,
                totalProjects: 8,
                successfulProjects: 6
            },
            {
                address: "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG",
                name: "Maya Soundwave",
                bio: "Music producer and visual artist creating immersive experiences",
                portfolioUrl: "https://mayasoundwave.com",
                reputationScore: 680,
                totalProjects: 12,
                successfulProjects: 10
            },
            {
                address: "ST3AM1A56AK2C1XAFJ4115ZSV26EB49BVQ10MGCS0",
                name: "Sam Lens",
                bio: "Street photographer capturing authentic moments in urban environments",
                portfolioUrl: "https://samlens.photo",
                reputationScore: 290,
                totalProjects: 5,
                successfulProjects: 3
            }
        ];
    }

    renderProjects() {
        const grid = document.getElementById('projectsGrid');
        const filteredProjects = this.getFilteredProjects();
        
        grid.innerHTML = filteredProjects.map(project => {
            const fundingPercentage = Math.min((project.currentFunding / project.fundingGoal) * 100, 100);
            const daysLeft = Math.max(Math.ceil((project.deadline - Date.now()) / (1000 * 60 * 60 * 24)), 0);
            const artist = this.artists.find(a => a.address === project.artist);
            
            return `
                <div class="project-card" onclick="window.talentPlatform.showProjectDetails(${project.id})">
                    <div class="project-header">
                        <div>
                            <div class="project-title">${project.title}</div>
                            <div style="font-size: 0.875rem; color: var(--text-secondary);">
                                by ${artist ? artist.name : 'Unknown Artist'}
                            </div>
                        </div>
                        <span class="project-status status-${project.status}">${project.status}</span>
                    </div>
                    <div class="project-description">${project.description}</div>
                    <div class="project-stats">
                        <div class="stat-row">
                            <span>Funding</span>
                            <span>${project.currentFunding} / ${project.fundingGoal} STX</span>
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: ${fundingPercentage}%"></div>
                        </div>
                        <div class="stat-row">
                            <span>Votes: ${project.votes}</span>
                            <span>${project.status === 'active' ? `${daysLeft} days left` : ''}</span>
                        </div>
                    </div>
                    <div class="project-actions">
                        ${project.status === 'active' ? `
                            <button class="btn btn-primary btn-small" onclick="event.stopPropagation(); window.talentPlatform.supportProject(${project.id})">
                                Support
                            </button>
                            <button class="btn btn-secondary btn-small" onclick="event.stopPropagation(); window.talentPlatform.voteProject(${project.id})">
                                Vote
                            </button>
                            ${project.collaborationOpen ? `
                                <button class="btn btn-warning btn-small" onclick="event.stopPropagation(); window.talentPlatform.requestCollaboration(${project.id})">
                                    Collaborate
                                </button>
                            ` : ''}
                        ` : ''}
                    </div>
                </div>
            `;
        }).join('');
    }

    renderArtists() {
        const grid = document.getElementById('artistsGrid');
        
        grid.innerHTML = this.artists.map(artist => {
            const successRate = artist.totalProjects > 0 ? Math.round((artist.successfulProjects / artist.totalProjects) * 100) : 0;
            
            return `
                <div class="artist-card" onclick="window.talentPlatform.showArtistProfile('${artist.address}')">
                    <div class="artist-name">${artist.name}</div>
                    <div class="artist-bio">${artist.bio}</div>
                    <div class="artist-stats">
                        <div class="stat-item">
                            <div class="stat-value">${artist.reputationScore}</div>
                            <div class="stat-label">Reputation</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value">${successRate}%</div>
                            <div class="stat-label">Success Rate</div>
                        </div>
                    </div>
                    <div style="font-size: 0.875rem; color: var(--text-secondary);">
                        ${artist.totalProjects} projects • ${artist.successfulProjects} completed
                    </div>
                </div>
            `;
        }).join('');
    }

    getFilteredProjects() {
        const statusFilter = document.getElementById('statusFilter').value;
        const searchTerm = document.getElementById('searchProjects').value.toLowerCase();
        
        return this.projects.filter(project => {
            const matchesStatus = statusFilter === 'all' || project.status === statusFilter;
            const matchesSearch = project.title.toLowerCase().includes(searchTerm) || 
                                project.description.toLowerCase().includes(searchTerm);
            return matchesStatus && matchesSearch;
        });
    }

    filterProjects() {
        this.renderProjects();
    }

    showCreateProjectModal() {
        if (!this.currentUser) {
            this.showToast('Please connect your wallet first', 'error');
            return;
        }
        this.showModal('createProjectModal');
    }

    async handleCreateProject(e) {
        e.preventDefault();
        
        if (!this.currentUser) {
            this.showToast('Please connect your wallet first', 'error');
            return;
        }

        const formData = new FormData(e.target);
        const projectData = {
            title: document.getElementById('projectTitle').value,
            description: document.getElementById('projectDescription').value,
            fundingGoal: parseFloat(document.getElementById('fundingGoal').value),
            duration: parseInt(document.getElementById('projectDuration').value),
            collaborationOpen: document.getElementById('collaborationOpen').checked
        };

        try {
            this.showLoading();
            
            const newProject = {
                id: this.projects.length + 1,
                ...projectData,
                artist: this.currentUser,
                currentFunding: 0,
                votes: 0,
                status: "active",
                deadline: Date.now() + (projectData.duration * 10 * 60 * 1000)
            };
            
            this.projects.unshift(newProject);
            this.renderProjects();
            this.hideModal('createProjectModal');
            this.showToast('Project created successfully!', 'success');
            
            document.getElementById('createProjectForm').reset();
        } catch (error) {
            this.showToast('Failed to create project', 'error');
        } finally {
            this.hideLoading();
        }
    }

    async supportProject(projectId) {
        if (!this.currentUser) {
            this.showToast('Please connect your wallet first', 'error');
            return;
        }

        const amount = prompt('Enter STX amount to support:');
        if (!amount || isNaN(amount) || parseFloat(amount) <= 0) {
            this.showToast('Invalid amount', 'error');
            return;
        }

        try {
            this.showLoading();
            
            const project = this.projects.find(p => p.id === projectId);
            if (project) {
                project.currentFunding += parseFloat(amount);
                this.renderProjects();
                this.showToast(`Successfully supported with ${amount} STX!`, 'success');
            }
        } catch (error) {
            this.showToast('Failed to support project', 'error');
        } finally {
            this.hideLoading();
        }
    }

    async voteProject(projectId) {
        if (!this.currentUser) {
            this.showToast('Please connect your wallet first', 'error');
            return;
        }

        try {
            this.showLoading();
            
            const project = this.projects.find(p => p.id === projectId);
            if (project) {
                project.votes += 1;
                this.renderProjects();
                this.showToast('Vote cast successfully!', 'success');
            }
        } catch (error) {
            this.showToast('Failed to vote', 'error');
        } finally {
            this.hideLoading();
        }
    }

    async requestCollaboration(projectId) {
        if (!this.currentUser) {
            this.showToast('Please connect your wallet first', 'error');
            return;
        }

        const message = prompt('Enter collaboration message:');
        if (!message) return;

        try {
            this.showLoading();
            this.showToast('Collaboration request sent!', 'success');
        } catch (error) {
            this.showToast('Failed to send collaboration request', 'error');
        } finally {
            this.hideLoading();
        }
    }

    showProjectDetails(projectId) {
        const project = this.projects.find(p => p.id === projectId);
        if (!project) return;

        const artist = this.artists.find(a => a.address === project.artist);
        const fundingPercentage = Math.min((project.currentFunding / project.fundingGoal) * 100, 100);
        const daysLeft = Math.max(Math.ceil((project.deadline - Date.now()) / (1000 * 60 * 60 * 24)), 0);

        document.getElementById('projectModalTitle').textContent = project.title;
        document.getElementById('projectModalContent').innerHTML = `
            <div style="padding: 1.5rem;">
                <div style="margin-bottom: 1rem;">
                    <span class="project-status status-${project.status}">${project.status}</span>
                </div>
                <p style="margin-bottom: 1.5rem; color: var(--text-secondary);">${project.description}</p>
                
                <div style="margin-bottom: 1.5rem;">
                    <h5 style="margin-bottom: 0.5rem;">Funding Progress</h5>
                    <div class="stat-row">
                        <span>${project.currentFunding} STX raised</span>
                        <span>Goal: ${project.fundingGoal} STX</span>
                    </div>
                    <div class="progress-bar" style="margin: 0.5rem 0;">
                        <div class="progress-fill" style="width: ${fundingPercentage}%"></div>
                    </div>
                    <div class="stat-row">
                        <span>${project.votes} votes</span>
                        <span>${project.status === 'active' ? `${daysLeft} days left` : ''}</span>
                    </div>
                </div>

                <div style="margin-bottom: 1.5rem;">
                    <h5 style="margin-bottom: 0.5rem;">Artist</h5>
                    <div style="color: var(--text-secondary);">
                        ${artist ? artist.name : 'Unknown Artist'} 
                        ${artist ? `• ${artist.reputationScore} reputation` : ''}
                    </div>
                </div>

                ${project.status === 'active' && this.currentUser ? `
                    <div class="support-form">
                        <input type="number" placeholder="STX amount" min="0.000001" step="0.000001" id="supportAmount">
                        <button class="btn btn-primary" onclick="window.talentPlatform.quickSupport(${project.id})">
                            Support
                        </button>
                    </div>
                ` : ''}

                ${project.collaborationOpen && project.status === 'active' && this.currentUser ? `
                    <div class="collaboration-section">
                        <h5>Request Collaboration</h5>
                        <textarea placeholder="Describe your collaboration proposal..." id="collabMessage"></textarea>
                        <button class="btn btn-warning" onclick="window.talentPlatform.sendCollabRequest(${project.id})">
                            Send Request
                        </button>
                    </div>
                ` : ''}
            </div>
        `;

        this.showModal('projectModal');
    }

    async quickSupport(projectId) {
        const amount = document.getElementById('supportAmount').value;
        if (!amount || parseFloat(amount) <= 0) {
            this.showToast('Please enter a valid amount', 'error');
            return;
        }
        
        try {
            this.showLoading();
            const project = this.projects.find(p => p.id === projectId);
            if (project) {
                project.currentFunding += parseFloat(amount);
                this.renderProjects();
                this.hideModal('projectModal');
                this.showToast(`Successfully supported with ${amount} STX!`, 'success');
            }
        } catch (error) {
            this.showToast('Failed to support project', 'error');
        } finally {
            this.hideLoading();
        }
    }

    async sendCollabRequest(projectId) {
        const message = document.getElementById('collabMessage').value;
        if (!message.trim()) {
            this.showToast('Please enter a collaboration message', 'error');
            return;
        }

        try {
            this.showLoading();
            this.hideModal('projectModal');
            this.showToast('Collaboration request sent!', 'success');
        } catch (error) {
            this.showToast('Failed to send collaboration request', 'error');
        } finally {
            this.hideLoading();
        }
    }

    showArtistProfile(address) {
        const artist = this.artists.find(a => a.address === address);
        if (!artist) return;

        console.log(`Showing profile for artist: ${artist.name}`);
        this.showToast(`Viewing ${artist.name}'s profile`, 'success');
    }

    async handleCreateArtistProfile(e) {
        e.preventDefault();
        
        if (!this.currentUser) {
            this.showToast('Please connect your wallet first', 'error');
            return;
        }

        const profileData = {
            name: document.getElementById('artistName').value,
            bio: document.getElementById('artistBio').value,
            portfolioUrl: document.getElementById('portfolioUrl').value
        };

        try {
            this.showLoading();
            
            const existingArtist = this.artists.find(a => a.address === this.currentUser);
            if (existingArtist) {
                Object.assign(existingArtist, profileData);
            } else {
                this.artists.push({
                    address: this.currentUser,
                    ...profileData,
                    reputationScore: 0,
                    totalProjects: 0,
                    successfulProjects: 0
                });
            }
            
            this.renderArtists();
            this.hideModal('artistModal');
            this.showToast('Artist profile saved!', 'success');
        } catch (error) {
            this.showToast('Failed to save profile', 'error');
        } finally {
            this.hideLoading();
        }
    }

    showModal(modalId) {
        document.getElementById(modalId).classList.add('active');
        document.body.style.overflow = 'hidden';
    }

    hideModal(modalId) {
        document.getElementById(modalId).classList.remove('active');
        document.body.style.overflow = '';
    }

    showLoading() {
        document.getElementById('loading').classList.add('active');
    }

    hideLoading() {
        document.getElementById('loading').classList.remove('active');
    }

    showToast(message, type = 'success') {
        const toast = document.getElementById('toast');
        const toastMessage = document.getElementById('toastMessage');
        
        toast.className = `toast ${type}`;
        toastMessage.textContent = message;
        toast.classList.add('active');
        
        setTimeout(() => {
            this.hideToast();
        }, 4000);
    }

    hideToast() {
        document.getElementById('toast').classList.remove('active');
    }
}

window.talentPlatform = new TalentPlatform();
