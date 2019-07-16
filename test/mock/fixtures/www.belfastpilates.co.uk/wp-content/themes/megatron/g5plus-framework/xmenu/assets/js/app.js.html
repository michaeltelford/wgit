/**
 * Created by hoantv on 2015-03-26.
 */
var APP_XMENU = APP_XMENU || {};
(function($) {
	"use strict";
	APP_XMENU = {
		timeOutHoverMenu: [],
		timeOutHoverOutMenu: [],

		initialize: function() {
			APP_XMENU.event();
		},
		event: function() {
			APP_XMENU.window_resize();
			APP_XMENU.menu_event();
			APP_XMENU.window_scroll();
			APP_XMENU.tabs_position(5);
			APP_XMENU.windowLoad();
		},
		windowLoad: function() {
			$(window).load(function() {
				$('header.main-header .x-nav-menu').each(function() {
					var main_menu = this;
					$('header.main-header .x-nav-menu > li').each(function() {
						APP_XMENU.process_menu_position(this);
						APP_XMENU.process_tab_padding(this, main_menu);
					});
				});

			});
		},
		window_scroll: function(){
			$(window).on('scroll',function(event){
				if (APP_XMENU.is_desktop()) {
					$('header.main-header .x-nav-menu > li').each(function() {
						APP_XMENU.process_menu_position(this);
					});
				}
			});
		},
		window_resize: function() {
			$(window).resize(function() {
				if (APP_XMENU.is_desktop()) {
					APP_XMENU.tabs_position(5);

					$('header.main-header .x-nav-menu').each(function() {
						var main_menu = this;
						$('header.main-header .x-nav-menu > li').each(function() {
							APP_XMENU.process_menu_position(this);
							APP_XMENU.process_tab_padding(this, main_menu);
						});
					});
				}
			});
		},
		tabs_position: function(number_retry) {
			$('header.main-header ul.x-nav-menu').each(function() {
				if ($(this).hasClass('x-nav-vmenu')) {
					return;
				}

				$('.x-sub-menu-tab', this).each(function(){
					var $this = $(this);
					var tab_left_width = $(this).parent().outerWidth();
					if ($('> li.x-menu-active', this).length == 0) {
						$('> li:first-child', this).addClass('x-menu-active');
					}
					$('> li', this).each(function(){
						$('> ul', this).css('left', tab_left_width + 'px');
					});

					$('> li.x-menu-active', this).each(function(){
						APP_XMENU.tab_position($(this));
					});
				});
				if (number_retry > 0) {
					setTimeout(function() {
						APP_XMENU.tabs_position(number_retry - 1);
					}, 500);
				}
			});
		},
		tab_position: function($tab) {
			var tab_right_height = 0;
			if ($('> ul', $tab).length != 0) {
				tab_right_height = $('> ul', $tab).outerHeight();
			}
			$tab.parent().css('min-height', tab_right_height + 'px');
		},
		menu_event: function() {
			$('header.main-header .x-sub-menu-tab > li:first-child').addClass('x-menu-active');

			APP_XMENU.process_menu_mobile_click();

			$('header.main-header .x-nav-menu').each(function(){
				if ($(this).hasClass('x-nav-vmenu')) {
					return;
				}
				var transition_name = APP_XMENU.get_transition_name(this);
				APP_XMENU.transition_menu(this, transition_name, this);

				$('.x-sub-menu-tab > li', this).hover(function(){
					if (!APP_XMENU.is_desktop()) {
						return;
					}
					$('> li', $(this).parent()).removeClass('x-menu-active');
					$(this).addClass('x-menu-active');
					APP_XMENU.tab_position($(this));
				}, function(){
				});
			});


		},
		process_menu_mobile_click: function() {
			$('.header-mobile-nav li.x-menu-item, header.header-left li.x-menu-item').click(function(event){
				if ($('> ul.x-sub-menu', this).length == 0) {
					return;
				}
				if ($( event.target ).closest($('> ul.x-sub-menu', this)).length > 0 ) {
					return;
				}

				if ($( event.target ).closest($('> a > span', this)).length > 0) {
					var baseUri = '';
					if ((typeof (event.target) != "undefined") && (event.target != null) && (typeof (event.target.baseURI) != "undefined") && (event.target.baseURI != null)) {
						var arrBaseUri = event.target.baseURI.split('#');
						if (arrBaseUri.length > 0) {
							baseUri = arrBaseUri[0];
						}

						var $aClicked = $('> a.x-menu-a-text', this);
						if ($aClicked.length > 0) {
							var clickUrl = $aClicked.attr('href');
							if ((typeof (clickUrl) != "undefined") && (clickUrl != null) && (clickUrl != '') && (clickUrl != '#')) {
								clickUrl = clickUrl.split('#')[0];
								if (baseUri != clickUrl) {
									return;
								}
							}

						}
					}
				}

				event.preventDefault();
				$(this).toggleClass('x-sub-menu-open');
				$('> ul.x-sub-menu', this).slideToggle();
			});
		},

		process_tab_padding: function(target, main_menu) {
			if (!APP_XMENU.is_desktop()) {
				return;
			}

			if ($(main_menu).hasClass('x-nav-vmenu')) {
				return;
			}
			var $this = $(target);
			if ($this.hasClass('x-item-menu-multi-column')) {
				var $tab = $('> ul.x-sub-menu > li.x-tabs', $this);
				if ($tab.length > 0) {
					$(' > ul.x-sub-menu', $this).addClass('no-padding');
				}
			}
			$('> ul.x-sub-menu > li').each(function() {
				APP_XMENU.process_tab_padding(this, main_menu);
			});
		},
		transition_menu: function(target, transition_name, main_menu) {
			var $this = $(target);
			if ($(main_menu).hasClass('x-nav-vmenu')) {
				return;
			}

			$('> li.x-menu-item', $this).each(function(){
				var transition_name_current = APP_XMENU.get_transition_name($('> ul', this));
				if (transition_name_current == '') {
					transition_name_current = transition_name;
				}
				var time_out_duration = 300;
				if (transition_name_current == '') {
					time_out_duration = 200;
				}
				var current_li_id = 0;
				$(this).hover(function() {
						if (!APP_XMENU.is_desktop()) {
							return;
						}

						var $this_li = $(this);
						current_li_id = $this_li.prop('id');
						if ($('.main-menu').hasClass('x-nav-vmenu')) {
							if ($this_li.offset().top - jQuery(window).scrollTop() - $(window).outerHeight()/2 > 0) {
								$('> ul', $this_li).removeClass('x-drop-from-bottom').addClass('x-drop-from-bottom');
							}
						}
						if (typeof (APP_XMENU.timeOutHoverMenu[$this_li.prop('id')]) != "undefined") {
							clearTimeout(APP_XMENU.timeOutHoverMenu[$this_li.prop('id')]);
						}

						APP_XMENU.timeOutHoverMenu[$this_li.prop('id')] = setTimeout(function() {
							$this_li.addClass('x-active');
							if (transition_name_current != '') {
								$('> ul', $this_li).addClass(transition_name_current);
							}

						}, time_out_duration);
					},
					function() {
						if (!APP_XMENU.is_desktop()) {
							return;
						}
						var $this_li = $(this);
						current_li_id = 0;
						if ($('.main-menu').hasClass('x-nav-vmenu')) {
							if ($this_li.offset().top - jQuery(window).scrollTop() - $(window).outerHeight()/2 > 0) {
								$('> ul', $this_li).removeClass('x-drop-from-bottom');
							}
						}

						clearTimeout(APP_XMENU.timeOutHoverMenu[$this_li.prop('id')]);
						APP_XMENU.timeOutHoverOutMenu[$this_li.prop('id')] = setTimeout(function() {
							if (current_li_id == $this_li.prop('id')) {
								return;
							}
							if ($this_li.hasClass('x-active')) {
								$('> ul', $this_li).addClass(transition_name_current + '-out');

								setTimeout(function(){
									if (transition_name_current != '') {
										$('> ul', $this_li).removeClass(transition_name_current);
										$('> ul', $this_li).removeClass(transition_name_current + '-out');
									}
									$($this_li).removeClass('x-active');
								}, time_out_duration);
							}
						}, 200);
					});

				if (!$(this).hasClass('x-item-menu-multi-column')) {
					APP_XMENU.transition_menu($('> ul.x-sub-menu', this), transition_name, main_menu);
				}
			});
		},

		get_transition_name: function(target) {
			var transition_name = '';
			if ($(target).hasClass('x-animate-slide-up')){
				transition_name = 'x-slide-up';
			}
			else if ($(target).hasClass('x-animate-slide-down')){
				transition_name = 'x-slide-down';
			}
			else if ($(target).hasClass('x-animate-slide-left')){
				transition_name = 'x-slide-left';
			}
			else if ($(target).hasClass('x-animate-slide-right')){
				transition_name = 'x-slide-right';
			}
			else if ($(target).hasClass('x-animate-fade-in')){
				transition_name = 'x-fade-in';
			}
			else if ($(target).hasClass('x-animate-sign-flip')){
				transition_name = 'x-sign-flip';
			}
			return transition_name;
		},

		process_menu_position: function(target) {
			if ($('.main-menu').hasClass('x-nav-vmenu')) {
				return;
			}
			var $this = $(target);
			var $menuBar = $('.x-nav-menu');
			var $parentMenu =  $(target).parent();
			if ($this.hasClass('x-pos-left-menu-parent')) {
				APP_XMENU.process_position_left_menu_parent(target);
			}
			else if ($this.hasClass('x-pos-right-menu-parent')) {
				APP_XMENU.process_position_right_menu_parent(target);
			}
			else if ($this.hasClass('x-pos-center-menu-parent')) {
				APP_XMENU.process_position_center_menu_parent(target);
			}
			else if ($this.hasClass('x-pos-left-menu-bar')) {
				APP_XMENU.process_position_left_menu_bar(target);
			}
			else if ($this.hasClass('x-pos-right-menu-bar')) {
				APP_XMENU.process_position_right_menu_bar(target);
			}
			else if ($this.hasClass('x-pos-full')) {
				//None
			}
			else {
				APP_XMENU.process_position_right_menu_parent(target);
			}
		},

		get_margin_left: function(target) {
			var margin_left = $(target).css('margin-left');
			try {
				margin_left = parseInt(margin_left.replace('px',''), 10);
			}
			catch (ex) {
				margin_left = 0;
			}
			return margin_left;
		},
		process_position_left_menu_parent: function(target) {
			var $this = $(target);
			var $menuBar = $('header.main-header .x-nav-menu');
			while (($menuBar.prop('tagName') != 'BODY') && ($menuBar.css('position') == 'static')) {
				$menuBar = $menuBar.parent();
			}



			var $sub_menu = $('> ul.x-sub-menu', $this);
			if ($sub_menu.length == 0) {
				return;
			}

			if ($menuBar.outerWidth() <= $sub_menu.outerWidth()) {
				$sub_menu.css('left','0');
				$sub_menu.css('right','0');
			}
			else {
				var margin_left = APP_XMENU.get_margin_left(target);
				var right = $menuBar.outerWidth() - $(target).outerWidth() - $(target).position().left - margin_left;
				if ($(target).outerWidth() + $(target).position().left + margin_left < $sub_menu.outerWidth()) {
					$sub_menu.css('left','0');
					$sub_menu.css('right','auto');
				}
				else {
					$sub_menu.css('left','auto');
					$sub_menu.css('right',right + 'px');
				}
			}
		},
		process_position_right_menu_parent: function(target) {
			var $this = $(target);
			var $menuBar = $('header.main-header .x-nav-menu');
			while (($menuBar.prop('tagName') != 'BODY') && ($menuBar.css('position') == 'static')) {
				$menuBar = $menuBar.parent();
			}

			var $sub_menu = $('> ul.x-sub-menu', $this);
			if ($sub_menu.length == 0) {
				return;
			}
			var margin_left = APP_XMENU.get_margin_left(target);
			if ($menuBar.outerWidth() <= $sub_menu.outerWidth()) {
				$sub_menu.css('left','0');
				$sub_menu.css('right','0');
			}
			else {
				if ($menuBar.outerWidth() - $(target).position().left - margin_left < $sub_menu.outerWidth()) {
					$sub_menu.css('left','auto');
					$sub_menu.css('right','0');
				}
				else {
					$sub_menu.css('left',($(target).position().left + margin_left) + 'px');
					$sub_menu.css('right', 'auto');
				}
			}
		},
		process_position_center_menu_parent: function(target) {
			var $this = $(target);
			var $menuBar = $('header.main-header .x-nav-menu');
			while (($menuBar.prop('tagName') != 'BODY') && ($menuBar.css('position') == 'static')) {
				$menuBar = $menuBar.parent();
			}

			var $sub_menu = $('> ul.x-sub-menu', $this);
			if ($sub_menu.length == 0) {
				return;
			}
			if ($menuBar.outerWidth() <= $sub_menu.outerWidth()) {
				$sub_menu.css('left','0');
				$sub_menu.css('right','0');
			}
			else {
				var margin_left = APP_XMENU.get_margin_left(target);
				var left = ($sub_menu.outerWidth() - $this.outerWidth() - margin_left)/2;
				if (left > $(target).position().left) {
					$sub_menu.css('left','0');
					$sub_menu.css('right','auto');
				}
				else if (left > $menuBar.outerWidth() - $(target).outerWidth() - $(target).position().left) {
					$sub_menu.css('left','auto');
					$sub_menu.css('right','0');
				}
				else {
					$sub_menu.css('left', ($(target).position().left - left) + 'px');
					$sub_menu.css('right', 'auto');
				}
			}
		},
		process_position_left_menu_bar: function(target) {
			var $this = $(target);
			var $sub_menu = $('> ul.x-sub-menu', $this);
			$sub_menu.css('left','0');
			$sub_menu.css('right','auto');
		},
		process_position_right_menu_bar: function(target) {
			var $this = $(target);
			var $sub_menu = $('> ul.x-sub-menu', $this);
			$sub_menu.css('left','auto');
			$sub_menu.css('right','0');
		},

		is_desktop: function() {
			var responsive_breakpoint = 991;
			var $body = $('body');
			if ((typeof ($body.attr('data-breakpoint')) != "undefined")
				&& !isNaN(parseInt($body.attr('data-breakpoint'), 10)) ) {
				responsive_breakpoint = parseInt($body.attr('data-breakpoint'), 10);
			}

			return window.matchMedia('(min-width: ' + (responsive_breakpoint + 1)  + 'px)').matches;
		}
	}
	$(document).ready(function(){
		APP_XMENU.initialize();
	});
})(jQuery);