/* ========================================
   SmashRank Landing Page - JavaScript
   Zero dependencies, pure vanilla JS
   ======================================== */

(function () {
  'use strict';

  // ─── DOM Elements ───
  const navbar = document.getElementById('navbar');
  const hamburger = document.getElementById('hamburger');
  const mobileMenu = document.getElementById('mobileMenu');
  const navLinks = document.querySelectorAll('.navbar__links a, .navbar__mobile a');
  const sections = document.querySelectorAll('section[id]');

  // ─── Navbar Scroll Effect ───
  function handleNavScroll() {
    navbar.classList.toggle('scrolled', window.scrollY > 50);
  }

  window.addEventListener('scroll', handleNavScroll, { passive: true });
  handleNavScroll(); // Initial check

  // ─── Hamburger Menu ───
  function openMenu() {
    mobileMenu.classList.add('open');
    hamburger.classList.add('active');
    navbar.classList.add('menu-open');
    hamburger.setAttribute('aria-expanded', 'true');
    document.body.style.overflow = 'hidden';
  }

  function closeMenu() {
    mobileMenu.classList.remove('open');
    hamburger.classList.remove('active');
    navbar.classList.remove('menu-open');
    hamburger.setAttribute('aria-expanded', 'false');
    document.body.style.overflow = '';
  }

  hamburger.addEventListener('click', function () {
    if (mobileMenu.classList.contains('open')) {
      closeMenu();
    } else {
      openMenu();
    }
  });

  // Close mobile menu on link click
  navLinks.forEach(function (link) {
    link.addEventListener('click', function () {
      if (mobileMenu.classList.contains('open')) {
        closeMenu();
      }
    });
  });

  // Close on Escape key
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && mobileMenu.classList.contains('open')) {
      closeMenu();
    }
  });

  // ─── Active Nav Link Highlighting ───
  var activeObserver = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (entry.isIntersecting) {
        var id = entry.target.getAttribute('id');
        document.querySelectorAll('.navbar__links a').forEach(function (link) {
          link.classList.toggle('active', link.getAttribute('href') === '#' + id);
        });
      }
    });
  }, {
    rootMargin: '-20% 0px -60% 0px',
    threshold: 0
  });

  sections.forEach(function (section) {
    activeObserver.observe(section);
  });

  // ─── Scroll Reveal Animations ───
  var revealObserver = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        revealObserver.unobserve(entry.target);
      }
    });
  }, {
    threshold: 0.12,
    rootMargin: '0px 0px -40px 0px'
  });

  document.querySelectorAll('.reveal, .reveal-left, .reveal-right').forEach(function (el) {
    revealObserver.observe(el);
  });

  // ─── FAQ Accordion ───
  document.querySelectorAll('.faq-question').forEach(function (question) {
    question.addEventListener('click', function () {
      var item = question.parentElement;
      var wasActive = item.classList.contains('active');
      var isExpanded = question.getAttribute('aria-expanded') === 'true';

      // Close all
      document.querySelectorAll('.faq-item').forEach(function (i) {
        i.classList.remove('active');
        i.querySelector('.faq-question').setAttribute('aria-expanded', 'false');
      });

      // Toggle current
      if (!wasActive) {
        item.classList.add('active');
        question.setAttribute('aria-expanded', 'true');
      }
    });
  });

  // ─── Stats Counter Animation ───
  function easeOutQuart(t) {
    return 1 - Math.pow(1 - t, 4);
  }

  function animateCounter(element, target) {
    var duration = 1500;
    var start = null;

    function step(timestamp) {
      if (!start) start = timestamp;
      var progress = Math.min((timestamp - start) / duration, 1);
      var easedProgress = easeOutQuart(progress);
      element.textContent = Math.round(target * easedProgress);

      if (progress < 1) {
        requestAnimationFrame(step);
      } else {
        element.textContent = target;
      }
    }

    requestAnimationFrame(step);
  }

  var statsAnimated = false;
  var statsObserver = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (entry.isIntersecting && !statsAnimated) {
        statsAnimated = true;
        document.querySelectorAll('.stat__number[data-target]').forEach(function (counter) {
          var target = parseInt(counter.getAttribute('data-target'), 10);
          animateCounter(counter, target);
        });
        statsObserver.unobserve(entry.target);
      }
    });
  }, { threshold: 0.3 });

  var statsSection = document.getElementById('numeros');
  if (statsSection) {
    statsObserver.observe(statsSection);
  }

  // ─── Smooth Scroll Polyfill (for older browsers) ───
  document.querySelectorAll('a[href^="#"]').forEach(function (anchor) {
    anchor.addEventListener('click', function (e) {
      var targetId = this.getAttribute('href');
      if (targetId === '#') return;

      var targetEl = document.querySelector(targetId);
      if (targetEl) {
        e.preventDefault();
        var offsetTop = targetEl.getBoundingClientRect().top + window.pageYOffset - 72;
        window.scrollTo({
          top: offsetTop,
          behavior: 'smooth'
        });
      }
    });
  });

})();
