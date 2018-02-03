<?php
class lr {
    function __construct() {
        add_action('init', array(&$this, 'init_feeds'));
    }
    
    function init_feeds() {
        add_feed('lr', array(&$this, 'lr'));
    }
    
    function lr() {
        $user = $this->_authenticate($_POST['username'], $_POST['password']);
        
        if ($user && current_user_can('administrator')) {
            $actions = array('post', 'delete', 'get_comments', 'add_comment');
            
            if (in_array($_POST['action'], $actions)) {    
                $this->{$_POST['action']}();
            }
        }
    }
    
    
	
    function post() {
        require_once(ABSPATH . 'wp-admin/includes/file.php');
        
        $category_ids = get_all_category_ids();
        $categories = array();
        foreach($category_ids as $cat_id) {
            $categories[get_cat_name($cat_id)] = $cat_id;
        } 
        
        $post_cats = array();
        $input_cats = explode(',', stripslashes(str_replace('"', '', $_POST['tags'])));
        foreach ($input_cats as $cat) {
            if (in_array($cat, array_keys($categories))) {
                $post_cats[] = $categories[$cat];
            }
        }
        
        $post = array('post_title' => $_POST['title'],
                      'post_content' => $_POST['desc'],
                      'post_status' => 'publish',
                      'post_category' => $post_cats,
                      );
        
        if (is_numeric($_POST['post_id']) && $_POST['post_id'] > 0) {
            $postid = $_POST['post_id'];
            $post['ID'] = $_POST['post_id'];
            $result = wp_update_post($post);
            
            if ($postid) {
                $ptid = get_post_thumbnail_id($postid);
                if ($ptid) {
                    wp_delete_attachment($ptid);
                    delete_post_thumbnail($postid);
                }
            }           
        } else {
            $postid = wp_insert_post($post);            
        }

        require_once(ABSPATH . 'wp-admin/includes/admin.php');
        $pid = media_handle_upload('photo', $postid);
        set_post_thumbnail($postid, $pid);

        print $postid;
    }
    
    function delete() {
        $id = $_POST['post_id'];
        
        if (is_numeric($id)) {
            $ptid = get_post_thumbnail_id($id);
            if ($ptid) {
                wp_delete_attachment($ptid);
                delete_post_thumbnail($id);
            }
            
            $state = wp_delete_post($id, 1);
            return intval($state);
        }
    }
                
    function get_comments() {
        $id = $_POST['post_id'];
        
        $output = '';
        if (is_numeric($id)) {
            $comments = get_comments('post_id='.$id);
            
            foreach ($comments as $comment) {
                $output .= '<comment id="'.$comment->comment_ID.'" author="'.$comment->comment_author.'" date="'.strtotime($comment->comment_date).'">'.$comment->comment_content."</comment>\n";
            }
        }
        $this->_output_xml("<comments>\n".$output."</comments>\n");
        
    }
    
    function add_comment() {
        $id = $_POST['post_id'];
        
        if (is_numeric($id)) {
            $time = current_time('mysql');
            
            wp_get_current_user();
            
            $data = array('comment_post_ID' => $id,
                          'comment_author' => $_POST['username'],
                          'comment_content' => $_POST['comment'],
                          'comment_date' => $time,
                          'user_id' => $current_user->ID,
                          'comment_approved' => 1);
            
            wp_insert_comment($data);            
        }
    }
            
    
    
    function _authenticate($user, $pass) {
		$user = wp_authenticate($user, $pass);
        
		if (is_wp_error($user)) {
			header('HTTP/1.1 403 Forbidden');
		}
        
		wp_set_current_user( $user->ID );
        
        return $user;
    }
    
    function _output_xml($data) {
        header('Content-Type: text/xml; charset=' . get_option('blog_charset'), true);
        header('Cache-Control: no-cache'); 
        
        print '<?xml version="1.0" encoding="'.get_option('blog_charset').'"?'.'>';
        print "\n<xml>\n$data\n</xml>";           
    }
}

?>