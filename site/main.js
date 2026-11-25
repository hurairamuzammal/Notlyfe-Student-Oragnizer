// =============================================================================
// Notlyfe Product Landing Page — Modern Native Interactions & Canvas Engine
// Zero Bloat • Ultra-Fluid Animations • FieldQuote-Inspired Depth
// =============================================================================

document.addEventListener('DOMContentLoaded', () => {
  initHeroCanvas();
  initScrollNav();
  initScrollProgressBar();
  initScenarioSwitcher();
  initCgpaSimulator();
  initQrLaserDemo();
  initHeroTilt();
  initFaqAccordion();
  initContactForm();
  initScrollReveal();
});

/**
 * 1. Interactive Canvas Particle & Grid Backdrop (Circuit/Node Grid)
 */
function initHeroCanvas() {
  const canvas = document.getElementById('canvas-backdrop');
  if (!canvas) return;

  const ctx = canvas.getContext('2d');
  let width, height;
  let particles = [];
  let mouse = { x: null, y: null, radius: 150 };

  const resize = () => {
    width = canvas.width = window.innerWidth;
    height = canvas.height = canvas.parentElement.offsetHeight || window.innerHeight;
    createParticles();
  };

  const createParticles = () => {
    particles = [];
    const count = Math.min(65, Math.floor((width * height) / 18000));
    for (let i = 0; i < count; i++) {
      particles.push({
        x: Math.random() * width,
        y: Math.random() * height,
        vx: (Math.random() - 0.5) * 0.45,
        vy: (Math.random() - 0.5) * 0.45,
        size: Math.random() * 2 + 1,
        alpha: Math.random() * 0.5 + 0.2
      });
    }
  };

  const draw = () => {
    ctx.clearRect(0, 0, width, height);

    // Draw connection lines
    for (let i = 0; i < particles.length; i++) {
      for (let j = i + 1; j < particles.length; j++) {
        const dx = particles[i].x - particles[j].x;
        const dy = particles[i].y - particles[j].y;
        const dist = Math.sqrt(dx * dx + dy * dy);

        if (dist < 120) {
          ctx.beginPath();
          ctx.moveTo(particles[i].x, particles[i].y);
          ctx.lineTo(particles[j].x, particles[j].y);
          ctx.strokeStyle = `rgba(245, 158, 11, ${0.12 * (1 - dist / 120)})`;
          ctx.lineWidth = 1;
          ctx.stroke();
        }
      }
    }

    // Draw particles
    particles.forEach(p => {
      p.x += p.vx;
      p.y += p.vy;

      if (p.x < 0 || p.x > width) p.vx *= -1;
      if (p.y < 0 || p.y > height) p.vy *= -1;

      // Mouse gentle repulsion
      if (mouse.x !== null) {
        const mdx = p.x - mouse.x;
        const mdy = p.y - mouse.y;
        const mdist = Math.sqrt(mdx * mdx + mdy * mdy);
        if (mdist < mouse.radius) {
          const force = (1 - mdist / mouse.radius) * 1.5;
          p.x += (mdx / mdist) * force;
          p.y += (mdy / mdist) * force;
        }
      }

      ctx.beginPath();
      ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(251, 191, 36, ${p.alpha})`;
      ctx.fill();
    });

    requestAnimationFrame(draw);
  };

  window.addEventListener('resize', resize);
  window.addEventListener('mousemove', (e) => {
    mouse.x = e.clientX;
    mouse.y = e.clientY;
  });
  window.addEventListener('mouseleave', () => {
    mouse.x = null;
    mouse.y = null;
  });

  resize();
  draw();
}

/**
 * 2. Sticky Navbar Blur & Background Transition
 */
function initScrollNav() {
  const nav = document.querySelector('.site-nav');
  if (!nav) return;

  const onScroll = () => {
    if (window.scrollY > 30) {
      nav.classList.add('scrolled');
    } else {
      nav.classList.remove('scrolled');
    }
  };

  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();
}

/**
 * 3. Top Scroll Reading Progress Line
 */
function initScrollProgressBar() {
  const line = document.querySelector('.scroll-progress-line');
  if (!line) return;

  const updateProgress = () => {
    const total = document.documentElement.scrollHeight - window.innerHeight;
    if (total <= 0) {
      line.style.width = '0%';
      return;
    }
    const ratio = Math.min(100, Math.max(0, (window.scrollY / total) * 100));
    line.style.width = `${ratio}%`;
  };

  window.addEventListener('scroll', updateProgress, { passive: true });
  updateProgress();
}

/**
 * 4. Interactive Student Scenarios Switcher
 */
function initScenarioSwitcher() {
  const tabs = document.querySelectorAll('.scenario-tab');
  const panels = document.querySelectorAll('.stage-scenario-panel');

  if (!tabs.length || !panels.length) return;

  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const targetId = tab.getAttribute('data-scenario');
      if (!targetId) return;

      tabs.forEach(t => t.classList.remove('active'));
      tab.classList.add('active');

      panels.forEach(panel => {
        if (panel.id === targetId) {
          panel.classList.add('active');
        } else {
          panel.classList.remove('active');
        }
      });
    });
  });
}

/**
 * 5. Interactive Target CGPA Simulation Widget (Scenario 3)
 */
function initCgpaSimulator() {
  const slider = document.getElementById('sim-grade-slider');
  const output = document.getElementById('sim-cgpa-val');
  const standingTag = document.getElementById('sim-standing-tag');
  if (!slider || !output) return;

  slider.addEventListener('input', (e) => {
    const gradeVal = parseFloat(e.target.value);
    // Base completed 60 credits @ 3.65 + current semester 16 credits @ gradeVal
    const prevPoints = 60 * 3.65;
    const currentPoints = 16 * gradeVal;
    const totalCgpa = (prevPoints + currentPoints) / 76;
    const formatted = totalCgpa.toFixed(2);

    output.textContent = formatted;

    if (standingTag) {
      if (totalCgpa >= 3.80) {
        standingTag.textContent = "Dean's Highest Honors (Top 3%)";
        standingTag.style.color = '#fbbf24';
      } else if (totalCgpa >= 3.50) {
        standingTag.textContent = "Dean's List Standing";
        standingTag.style.color = '#10b981';
      } else {
        standingTag.textContent = 'Good Academic Standing';
        standingTag.style.color = '#cbd5e1';
      }
    }
  });
}

/**
 * 6. Interactive QR Scanner Laser Trigger Demo (Scenario 2)
 */
function initQrLaserDemo() {
  const scanBtn = document.getElementById('qr-scan-action-btn');
  const scanStatus = document.getElementById('qr-scan-result-text');
  if (!scanBtn || !scanStatus) return;

  scanBtn.addEventListener('click', () => {
    scanBtn.disabled = true;
    scanBtn.innerHTML = 'Scanning QR Code...';
    scanStatus.innerHTML = '<span style="color: var(--amber-light);">Analyzing payload...</span>';

    setTimeout(() => {
      scanStatus.innerHTML = '<span style="color: #10b981; font-weight: 700;">✓ CS301 Networks Syllabus (14 Weeks) &amp; Lab Code Synchronized into Hive Box!</span>';
      scanBtn.disabled = false;
      scanBtn.innerHTML = 'Scan Another Code';
    }, 1100);
  });
}

/**
 * 7. Hero Dashboard 3D Tilt Effect
 */
function initHeroTilt() {
  const card = document.querySelector('.hero-glass-dashboard');
  if (!card) return;

  if (window.matchMedia('(pointer: coarse)').matches) return;

  card.addEventListener('mousemove', (e) => {
    const rect = card.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const centerX = rect.width / 2;
    const centerY = rect.height / 2;

    const rotY = ((x - centerX) / centerX) * 6;
    const rotX = -((y - centerY) / centerY) * 6;

    card.style.transform = `perspective(800px) rotateX(${rotX.toFixed(2)}deg) rotateY(${rotY.toFixed(2)}deg) translateY(-2px)`;
  });

  card.addEventListener('mouseleave', () => {
    card.style.transform = 'perspective(800px) rotateX(0deg) rotateY(0deg) translateY(0)';
  });
}

/**
 * 8. FAQ Accordion Toggle
 */
function initFaqAccordion() {
  const items = document.querySelectorAll('.faq-accordion-item');

  items.forEach(item => {
    const btn = item.querySelector('.faq-trigger-btn');
    if (!btn) return;

    btn.addEventListener('click', () => {
      const wasActive = item.classList.contains('active');

      items.forEach(other => other.classList.remove('active'));

      if (!wasActive) {
        item.classList.add('active');
      }
    });
  });
}

/**
 * 9. Interactive Contact Form Submission
 */
function initContactForm() {
  const form = document.getElementById('contact-form');
  const feedback = document.getElementById('contact-feedback');
  const submitBtn = document.getElementById('contact-submit-btn');

  if (!form || !feedback || !submitBtn) return;

  form.addEventListener('submit', (e) => {
    e.preventDefault();

    const name = form.querySelector('[name="name"]').value.trim();
    const email = form.querySelector('[name="email"]').value.trim();
    const message = form.querySelector('[name="message"]').value.trim();

    if (!name || !email || !message) {
      alert('Please fill out all required fields.');
      return;
    }

    submitBtn.disabled = true;
    submitBtn.textContent = 'Sending Message...';

    setTimeout(() => {
      form.reset();
      submitBtn.disabled = false;
      submitBtn.textContent = 'Send Message';
      feedback.style.display = 'block';
      feedback.scrollIntoView({ behavior: 'smooth', block: 'nearest' });

      setTimeout(() => {
        feedback.style.display = 'none';
      }, 7000);
    }, 900);
  });
}

/**
 * 10. IntersectionObserver Scroll Reveal
 */
function initScrollReveal() {
  const sections = document.querySelectorAll('.fade-in-section');
  if (!sections.length) return;

  if (!('IntersectionObserver' in window)) {
    sections.forEach(s => s.classList.add('is-visible'));
    return;
  }

  const observer = new IntersectionObserver((entries, obs) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('is-visible');
        obs.unobserve(entry.target);
      }
    });
  }, {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
  });

  sections.forEach(s => observer.observe(s));
}
