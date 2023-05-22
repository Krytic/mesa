! ***********************************************************************
!
!   Copyright (C) 2010-2022  The MESA Team, Bill Paxton & Matthias Fabry
!
!   MESA is free software; you can use it and/or modify
!   it under the combined terms and restrictions of the MESA MANIFESTO
!   and the GNU General Library Public License as published
!   by the Free Software Foundation; either version 2 of the License,
!   or (at your option) any later version.
!
!   You should have received a copy of the MESA MANIFESTO along with
!   this software; if not, it is available at the mesa website:
!   http://mesa.sourceforge.net/
!
!   MESA is distributed in the hope that it will be useful,
!   but WITHOUT ANY WARRANTY; without even the implied warranty of
!   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
!   See the GNU Library General Public License for more details.
!
!   You should have received a copy of the GNU Library General Public License
!   along with this software; if not, write to the Free Software
!   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
!
! ***********************************************************************

module pgbinary

   use binary_def
   use const_def
   use chem_def, only: category_name
   use rates_def, only: i_rate
   use pgbinary_support
   use pgstar, only: pgstar_clear, read_pgstar_data, &
      update_pgstar_history_file, update_pgstar_data

   implicit none


contains

   ! pgbinary interface
   subroutine start_new_run_for_pgbinary(b, ierr) ! reset logs
      use binary_def, only: binary_info
      type (binary_info), pointer :: b
      integer, intent(out) :: ierr
      call do_start_new_run_for_pgbinary(b, ierr)
   end subroutine start_new_run_for_pgbinary


   subroutine restart_run_for_pgbinary(b, ierr)
      use binary_def, only: binary_info
      type (binary_info), pointer :: b
      integer, intent(out) :: ierr
      call do_restart_run_for_pgbinary(b, ierr)
   end subroutine restart_run_for_pgbinary


   subroutine read_pgbinary_controls(b, ierr)
      use binary_def, only: binary_info
      type (binary_info), pointer :: b
      integer, intent(out) :: ierr
      call do_read_pgbinary_controls(b, 'inlist', ierr)
   end subroutine read_pgbinary_controls


   subroutine read_pgbinary_inlist(b, inlist_fname, ierr)
      use binary_def, only: binary_info
      type (binary_info), pointer :: b
      character(*), intent(in) :: inlist_fname
      integer, intent(out) :: ierr
      call do_read_pgbinary_controls(b, inlist_fname, ierr)
   end subroutine read_pgbinary_inlist

   subroutine update_pgbinary_plots(b, must_write_files, ierr)
      use binary_def, only: binary_info
      type (binary_info), pointer :: b
      logical, intent(in) :: must_write_files
      integer, intent(out) :: ierr
      call do_pgbinary_plots(&
         b, must_write_files, &
         ierr)
   end subroutine update_pgbinary_plots


   subroutine do_create_file_name(b, dir, prefix, name)
      use pgbinary_support, only: create_file_name
      type (binary_info), pointer :: b
      character (len = *), intent(in) :: dir, prefix
      character (len = *), intent(out) :: name
      call create_file_name(b, dir, prefix, name)
   end subroutine do_create_file_name


   subroutine do_write_plot_to_file(b, p, filename, ierr)
      use binary_def, only: binary_info, pgbinary_win_file_data
      use pgbinary_support, only: write_plot_to_file
      type (binary_info), pointer :: b
      type (pgbinary_win_file_data), pointer :: p
      character (len = *), intent(in) :: filename
      integer, intent(out) :: ierr
      call write_plot_to_file(b, p, filename, ierr)
   end subroutine do_write_plot_to_file


   subroutine do_show_pgbinary_annotations(&
      b, show_annotation1, show_annotation2, show_annotation3)
      use pgbinary_support, only: show_annotations
      type (binary_info), pointer :: b
      logical, intent(in) :: &
         show_annotation1, show_annotation2, show_annotation3
      call show_annotations(&
         b, show_annotation1, show_annotation2, show_annotation3)
   end subroutine do_show_pgbinary_annotations


   subroutine do_start_new_run_for_pgbinary(b, ierr) ! reset logs
      use utils_lib
      type (binary_info), pointer :: b
      integer, intent(out) :: ierr
      integer :: iounit
      character (len = strlen) :: fname
      logical :: fexist
      ierr = 0
      fname = trim(b% photo_directory) // '/pgbinary.dat'
      inquire(file = trim(fname), exist = fexist)
      if (fexist) then
         open(newunit = iounit, file = trim(fname), status = 'replace', action = 'write')
         close(iounit)
      end if
      call pgbinary_clear(b)
   end subroutine do_start_new_run_for_pgbinary


   subroutine do_restart_run_for_pgbinary(b, ierr)
      type (binary_info), pointer :: b
      integer, intent(out) :: ierr
      logical :: fexists
      ierr = 0
      if (.not. b% job% pgbinary_flag) return
      call pgbinary_clear(b)
      call read_pgbinary_data(b, ierr)
      if (ierr /= 0) then
         write(*, *) 'failed in read_pgbinary_data'
         ierr = 0
      end if
      ! read pgstar if present
      if (b% have_star_1) then
         inquire(file = trim(b% s1% log_directory) // '/pgstar.dat', exist = fexists)
         if (fexists) then
            call pgstar_clear(b% s1)
            call read_pgstar_data(b% s1, ierr)
         end if
      end if
      if (b% have_star_2) then
         inquire(file = trim(b% s2% log_directory) // '/pgstar.dat', exist = fexists)
         if (fexists) then
            call pgstar_clear(b% s2)
            call read_pgstar_data(b% s2, ierr)
         end if
      end if
   end subroutine do_restart_run_for_pgbinary


   subroutine do_read_pgbinary_controls(b, inlist_fname, ierr)
      use pgbinary_ctrls_io, only: read_pgbinary
      type (binary_info), pointer :: b
      character(*), intent(in) :: inlist_fname
      integer, intent(out) :: ierr
      ierr = 0
      call read_pgbinary(b, inlist_fname, ierr)
      if (ierr /= 0) then
         write(*, *) 'pgbinary failed in reading ' // trim(inlist_fname)
         return
      end if
      call set_win_file_data(b, ierr)
   end subroutine do_read_pgbinary_controls


   subroutine set_win_file_data(b, ierr)
      use pgbinary_summary_history, only: summary_history_plot
      use pgbinary_grid, only: &
         grid1_plot, grid2_plot, grid3_plot, grid4_plot, &
         grid5_plot, grid6_plot, grid7_plot, grid8_plot, grid9_plot
      use pgbinary_summary, only: &
         Text_Summary1_Plot, Text_Summary2_Plot, Text_Summary3_Plot, &
         Text_Summary4_Plot, Text_Summary5_Plot, Text_Summary6_Plot, &
         Text_Summary7_Plot, Text_Summary8_Plot, Text_Summary9_Plot
      use pgbinary_history_panels, only: &
         History_Panels1_plot, History_Panels2_plot, History_Panels3_plot, &
         History_Panels4_plot, History_Panels5_plot, History_Panels6_plot, &
         History_Panels7_plot, History_Panels8_plot, History_Panels9_plot
      use pgbinary_hist_track, only: &
         History_Track1_plot, History_Track2_plot, History_Track3_plot, &
         History_Track4_plot, History_Track5_plot, History_Track6_plot, &
         History_Track7_plot, History_Track8_plot, History_Track9_plot
      use pgbinary_star_hist_track, only: &
         Star_History_Track1_plot, Star_History_Track2_plot, Star_History_Track3_plot, &
         Star_History_Track4_plot, Star_History_Track5_plot, Star_History_Track6_plot, &
         Star_History_Track7_plot, Star_History_Track8_plot, Star_History_Track9_plot
      use pgbinary_star, only: &
         Star1_plot, Star2_plot
      use pgbinary_orbit, only: &
         Orbit_plot
      type (binary_info), pointer :: b
      integer, intent(out) :: ierr

      type (pgbinary_win_file_data), pointer :: p
      integer :: i

      ! store win and file info in records

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Text_Summary1)
      p% plot => Text_Summary1_Plot
      p% id = i_Binary_Text_Summary1
      p% name = 'Text_Summary(1)'
      p% win_flag = b% pg% Text_Summary_win_flag(1)
      p% win_width = b% pg% Text_Summary_win_width(1)
      p% win_aspect_ratio = b% pg% Text_Summary_win_aspect_ratio(1)
      p% file_flag = b% pg% Text_Summary_file_flag(1)
      p% file_dir = b% pg% Text_Summary_file_dir(1)
      p% file_prefix = b% pg% Text_Summary_file_prefix(1)
      p% file_interval = b% pg% Text_Summary_file_interval(1)
      p% file_width = b% pg% Text_Summary_file_width(1)
      p% file_aspect_ratio = b% pg% Text_Summary_file_aspect_ratio(1)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Text_Summary2)
      p% plot => Text_Summary2_Plot
      p% id = i_Binary_Text_Summary2
      p% name = 'Text_Summary(2)'
      p% win_flag = b% pg% Text_Summary_win_flag(2)
      p% win_width = b% pg% Text_Summary_win_width(2)
      p% win_aspect_ratio = b% pg% Text_Summary_win_aspect_ratio(2)
      p% file_flag = b% pg% Text_Summary_file_flag(2)
      p% file_dir = b% pg% Text_Summary_file_dir(2)
      p% file_prefix = b% pg% Text_Summary_file_prefix(2)
      p% file_interval = b% pg% Text_Summary_file_interval(2)
      p% file_width = b% pg% Text_Summary_file_width(2)
      p% file_aspect_ratio = b% pg% Text_Summary_file_aspect_ratio(2)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Text_Summary3)
      p% plot => Text_Summary3_Plot
      p% id = i_Binary_Text_Summary3
      p% name = 'Text_Summary(3)'
      p% win_flag = b% pg% Text_Summary_win_flag(3)
      p% win_width = b% pg% Text_Summary_win_width(3)
      p% win_aspect_ratio = b% pg% Text_Summary_win_aspect_ratio(3)
      p% file_flag = b% pg% Text_Summary_file_flag(3)
      p% file_dir = b% pg% Text_Summary_file_dir(3)
      p% file_prefix = b% pg% Text_Summary_file_prefix(3)
      p% file_interval = b% pg% Text_Summary_file_interval(3)
      p% file_width = b% pg% Text_Summary_file_width(3)
      p% file_aspect_ratio = b% pg% Text_Summary_file_aspect_ratio(3)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Text_Summary4)
      p% plot => Text_Summary4_Plot
      p% id = i_Binary_Text_Summary4
      p% name = 'Text_Summary(4)'
      p% win_flag = b% pg% Text_Summary_win_flag(4)
      p% win_width = b% pg% Text_Summary_win_width(4)
      p% win_aspect_ratio = b% pg% Text_Summary_win_aspect_ratio(4)
      p% file_flag = b% pg% Text_Summary_file_flag(4)
      p% file_dir = b% pg% Text_Summary_file_dir(4)
      p% file_prefix = b% pg% Text_Summary_file_prefix(4)
      p% file_interval = b% pg% Text_Summary_file_interval(4)
      p% file_width = b% pg% Text_Summary_file_width(4)
      p% file_aspect_ratio = b% pg% Text_Summary_file_aspect_ratio(4)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Text_Summary5)
      p% plot => Text_Summary5_Plot
      p% id = i_Binary_Text_Summary5
      p% name = 'Text_Summary(5)'
      p% win_flag = b% pg% Text_Summary_win_flag(5)
      p% win_width = b% pg% Text_Summary_win_width(5)
      p% win_aspect_ratio = b% pg% Text_Summary_win_aspect_ratio(5)
      p% file_flag = b% pg% Text_Summary_file_flag(5)
      p% file_dir = b% pg% Text_Summary_file_dir(5)
      p% file_prefix = b% pg% Text_Summary_file_prefix(5)
      p% file_interval = b% pg% Text_Summary_file_interval(5)
      p% file_width = b% pg% Text_Summary_file_width(5)
      p% file_aspect_ratio = b% pg% Text_Summary_file_aspect_ratio(5)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Text_Summary6)
      p% plot => Text_Summary6_Plot
      p% id = i_Binary_Text_Summary6
      p% name = 'Text_Summary(6)'
      p% win_flag = b% pg% Text_Summary_win_flag(6)
      p% win_width = b% pg% Text_Summary_win_width(6)
      p% win_aspect_ratio = b% pg% Text_Summary_win_aspect_ratio(6)
      p% file_flag = b% pg% Text_Summary_file_flag(6)
      p% file_dir = b% pg% Text_Summary_file_dir(6)
      p% file_prefix = b% pg% Text_Summary_file_prefix(6)
      p% file_interval = b% pg% Text_Summary_file_interval(6)
      p% file_width = b% pg% Text_Summary_file_width(6)
      p% file_aspect_ratio = b% pg% Text_Summary_file_aspect_ratio(6)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Text_Summary7)
      p% plot => Text_Summary7_Plot
      p% id = i_Binary_Text_Summary7
      p% name = 'Text_Summary(7)'
      p% win_flag = b% pg% Text_Summary_win_flag(7)
      p% win_width = b% pg% Text_Summary_win_width(7)
      p% win_aspect_ratio = b% pg% Text_Summary_win_aspect_ratio(7)
      p% file_flag = b% pg% Text_Summary_file_flag(7)
      p% file_dir = b% pg% Text_Summary_file_dir(7)
      p% file_prefix = b% pg% Text_Summary_file_prefix(7)
      p% file_interval = b% pg% Text_Summary_file_interval(7)
      p% file_width = b% pg% Text_Summary_file_width(7)
      p% file_aspect_ratio = b% pg% Text_Summary_file_aspect_ratio(7)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Text_Summary8)
      p% plot => Text_Summary8_Plot
      p% id = i_Binary_Text_Summary8
      p% name = 'Text_Summary(8)'
      p% win_flag = b% pg% Text_Summary_win_flag(8)
      p% win_width = b% pg% Text_Summary_win_width(8)
      p% win_aspect_ratio = b% pg% Text_Summary_win_aspect_ratio(8)
      p% file_flag = b% pg% Text_Summary_file_flag(8)
      p% file_dir = b% pg% Text_Summary_file_dir(8)
      p% file_prefix = b% pg% Text_Summary_file_prefix(8)
      p% file_interval = b% pg% Text_Summary_file_interval(8)
      p% file_width = b% pg% Text_Summary_file_width(8)
      p% file_aspect_ratio = b% pg% Text_Summary_file_aspect_ratio(8)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Text_Summary9)
      p% plot => Text_Summary9_Plot
      p% id = i_Binary_Text_Summary9
      p% name = 'Text_Summary(9)'
      p% win_flag = b% pg% Text_Summary_win_flag(9)
      p% win_width = b% pg% Text_Summary_win_width(9)
      p% win_aspect_ratio = b% pg% Text_Summary_win_aspect_ratio(9)
      p% file_flag = b% pg% Text_Summary_file_flag(9)
      p% file_dir = b% pg% Text_Summary_file_dir(9)
      p% file_prefix = b% pg% Text_Summary_file_prefix(9)
      p% file_interval = b% pg% Text_Summary_file_interval(9)
      p% file_width = b% pg% Text_Summary_file_width(9)
      p% file_aspect_ratio = b% pg% Text_Summary_file_aspect_ratio(9)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Hist_Panels1)
      p% plot => History_Panels1_plot
      p% id = i_Binary_Hist_Panels1
      p% name = 'History_Panels1'
      p% win_flag = b% pg% History_Panels_win_flag(1)
      p% win_width = b% pg% History_Panels_win_width(1)
      p% win_aspect_ratio = b% pg% History_Panels_win_aspect_ratio(1)
      p% file_flag = b% pg% History_Panels_file_flag(1)
      p% file_dir = b% pg% History_Panels_file_dir(1)
      p% file_prefix = b% pg% History_Panels_file_prefix(1)
      p% file_interval = b% pg% History_Panels_file_interval(1)
      p% file_width = b% pg% History_Panels_file_width(1)
      p% file_aspect_ratio = b% pg% History_Panels_file_aspect_ratio(1)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Hist_Panels2)
      p% plot => History_Panels2_plot
      p% id = i_Binary_Hist_Panels2
      p% name = 'History_Panels2'
      p% win_flag = b% pg% History_Panels_win_flag(2)
      p% win_width = b% pg% History_Panels_win_width(2)
      p% win_aspect_ratio = b% pg% History_Panels_win_aspect_ratio(2)
      p% file_flag = b% pg% History_Panels_file_flag(2)
      p% file_dir = b% pg% History_Panels_file_dir(2)
      p% file_prefix = b% pg% History_Panels_file_prefix(2)
      p% file_interval = b% pg% History_Panels_file_interval(2)
      p% file_width = b% pg% History_Panels_file_width(2)
      p% file_aspect_ratio = b% pg% History_Panels_file_aspect_ratio(2)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Hist_Panels3)
      p% plot => History_Panels3_plot
      p% id = i_Binary_Hist_Panels3
      p% name = 'History_Panels3'
      p% win_flag = b% pg% History_Panels_win_flag(3)
      p% win_width = b% pg% History_Panels_win_width(3)
      p% win_aspect_ratio = b% pg% History_Panels_win_aspect_ratio(3)
      p% file_flag = b% pg% History_Panels_file_flag(3)
      p% file_dir = b% pg% History_Panels_file_dir(3)
      p% file_prefix = b% pg% History_Panels_file_prefix(3)
      p% file_interval = b% pg% History_Panels_file_interval(3)
      p% file_width = b% pg% History_Panels_file_width(3)
      p% file_aspect_ratio = b% pg% History_Panels_file_aspect_ratio(3)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Hist_Panels4)
      p% plot => History_Panels4_plot
      p% id = i_Binary_Hist_Panels4
      p% name = 'History_Panels4'
      p% win_flag = b% pg% History_Panels_win_flag(4)
      p% win_width = b% pg% History_Panels_win_width(4)
      p% win_aspect_ratio = b% pg% History_Panels_win_aspect_ratio(4)
      p% file_flag = b% pg% History_Panels_file_flag(4)
      p% file_dir = b% pg% History_Panels_file_dir(4)
      p% file_prefix = b% pg% History_Panels_file_prefix(4)
      p% file_interval = b% pg% History_Panels_file_interval(4)
      p% file_width = b% pg% History_Panels_file_width(4)
      p% file_aspect_ratio = b% pg% History_Panels_file_aspect_ratio(4)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Hist_Panels5)
      p% plot => History_Panels5_plot
      p% id = i_Binary_Hist_Panels5
      p% name = 'History_Panels5'
      p% win_flag = b% pg% History_Panels_win_flag(5)
      p% win_width = b% pg% History_Panels_win_width(5)
      p% win_aspect_ratio = b% pg% History_Panels_win_aspect_ratio(5)
      p% file_flag = b% pg% History_Panels_file_flag(5)
      p% file_dir = b% pg% History_Panels_file_dir(5)
      p% file_prefix = b% pg% History_Panels_file_prefix(5)
      p% file_interval = b% pg% History_Panels_file_interval(5)
      p% file_width = b% pg% History_Panels_file_width(5)
      p% file_aspect_ratio = b% pg% History_Panels_file_aspect_ratio(5)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Hist_Panels6)
      p% plot => History_Panels6_plot
      p% id = i_Binary_Hist_Panels6
      p% name = 'History_Panels6'
      p% win_flag = b% pg% History_Panels_win_flag(6)
      p% win_width = b% pg% History_Panels_win_width(6)
      p% win_aspect_ratio = b% pg% History_Panels_win_aspect_ratio(6)
      p% file_flag = b% pg% History_Panels_file_flag(6)
      p% file_dir = b% pg% History_Panels_file_dir(6)
      p% file_prefix = b% pg% History_Panels_file_prefix(6)
      p% file_interval = b% pg% History_Panels_file_interval(6)
      p% file_width = b% pg% History_Panels_file_width(6)
      p% file_aspect_ratio = b% pg% History_Panels_file_aspect_ratio(6)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Hist_Panels7)
      p% plot => History_Panels7_plot
      p% id = i_Binary_Hist_Panels7
      p% name = 'History_Panels7'
      p% win_flag = b% pg% History_Panels_win_flag(7)
      p% win_width = b% pg% History_Panels_win_width(7)
      p% win_aspect_ratio = b% pg% History_Panels_win_aspect_ratio(7)
      p% file_flag = b% pg% History_Panels_file_flag(7)
      p% file_dir = b% pg% History_Panels_file_dir(7)
      p% file_prefix = b% pg% History_Panels_file_prefix(7)
      p% file_interval = b% pg% History_Panels_file_interval(7)
      p% file_width = b% pg% History_Panels_file_width(7)
      p% file_aspect_ratio = b% pg% History_Panels_file_aspect_ratio(7)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Hist_Panels8)
      p% plot => History_Panels8_plot
      p% id = i_Binary_Hist_Panels8
      p% name = 'History_Panels8'
      p% win_flag = b% pg% History_Panels_win_flag(8)
      p% win_width = b% pg% History_Panels_win_width(8)
      p% win_aspect_ratio = b% pg% History_Panels_win_aspect_ratio(8)
      p% file_flag = b% pg% History_Panels_file_flag(8)
      p% file_dir = b% pg% History_Panels_file_dir(8)
      p% file_prefix = b% pg% History_Panels_file_prefix(8)
      p% file_interval = b% pg% History_Panels_file_interval(8)
      p% file_width = b% pg% History_Panels_file_width(8)
      p% file_aspect_ratio = b% pg% History_Panels_file_aspect_ratio(8)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Hist_Panels9)
      p% plot => History_Panels9_plot
      p% id = i_Binary_Hist_Panels9
      p% name = 'History_Panels9'
      p% win_flag = b% pg% History_Panels_win_flag(9)
      p% win_width = b% pg% History_Panels_win_width(9)
      p% win_aspect_ratio = b% pg% History_Panels_win_aspect_ratio(9)
      p% file_flag = b% pg% History_Panels_file_flag(9)
      p% file_dir = b% pg% History_Panels_file_dir(9)
      p% file_prefix = b% pg% History_Panels_file_prefix(9)
      p% file_interval = b% pg% History_Panels_file_interval(9)
      p% file_width = b% pg% History_Panels_file_width(9)
      p% file_aspect_ratio = b% pg% History_Panels_file_aspect_ratio(9)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Hist_Track1)
      p% plot => History_Track1_plot
      p% id = i_Binary_Hist_Track1
      p% name = 'History_Track1'
      p% win_flag = b% pg% History_Track_win_flag(1)
      p% win_width = b% pg% History_Track_win_width(1)
      p% win_aspect_ratio = b% pg% History_Track_win_aspect_ratio(1)
      p% file_flag = b% pg% History_Track_file_flag(1)
      p% file_dir = b% pg% History_Track_file_dir(1)
      p% file_prefix = b% pg% History_Track_file_prefix(1)
      p% file_interval = b% pg% History_Track_file_interval(1)
      p% file_width = b% pg% History_Track_file_width(1)
      p% file_aspect_ratio = b% pg% History_Track_file_aspect_ratio(1)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Hist_Track2)
      p% plot => History_Track2_plot
      p% id = i_Binary_Hist_Track2
      p% name = 'History_Track2'
      p% win_flag = b% pg% History_Track_win_flag(2)
      p% win_width = b% pg% History_Track_win_width(2)
      p% win_aspect_ratio = b% pg% History_Track_win_aspect_ratio(2)
      p% file_flag = b% pg% History_Track_file_flag(2)
      p% file_dir = b% pg% History_Track_file_dir(2)
      p% file_prefix = b% pg% History_Track_file_prefix(2)
      p% file_interval = b% pg% History_Track_file_interval(2)
      p% file_width = b% pg% History_Track_file_width(2)
      p% file_aspect_ratio = b% pg% History_Track_file_aspect_ratio(2)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Hist_Track3)
      p% plot => History_Track3_plot
      p% id = i_Binary_Hist_Track3
      p% name = 'History_Track3'
      p% win_flag = b% pg% History_Track_win_flag(3)
      p% win_width = b% pg% History_Track_win_width(3)
      p% win_aspect_ratio = b% pg% History_Track_win_aspect_ratio(3)
      p% file_flag = b% pg% History_Track_file_flag(3)
      p% file_dir = b% pg% History_Track_file_dir(3)
      p% file_prefix = b% pg% History_Track_file_prefix(3)
      p% file_interval = b% pg% History_Track_file_interval(3)
      p% file_width = b% pg% History_Track_file_width(3)
      p% file_aspect_ratio = b% pg% History_Track_file_aspect_ratio(3)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Hist_Track4)
      p% plot => History_Track4_plot
      p% id = i_Binary_Hist_Track4
      p% name = 'History_Track4'
      p% win_flag = b% pg% History_Track_win_flag(4)
      p% win_width = b% pg% History_Track_win_width(4)
      p% win_aspect_ratio = b% pg% History_Track_win_aspect_ratio(4)
      p% file_flag = b% pg% History_Track_file_flag(4)
      p% file_dir = b% pg% History_Track_file_dir(4)
      p% file_prefix = b% pg% History_Track_file_prefix(4)
      p% file_interval = b% pg% History_Track_file_interval(4)
      p% file_width = b% pg% History_Track_file_width(4)
      p% file_aspect_ratio = b% pg% History_Track_file_aspect_ratio(4)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Hist_Track5)
      p% plot => History_Track5_plot
      p% id = i_Binary_Hist_Track5
      p% name = 'History_Track5'
      p% win_flag = b% pg% History_Track_win_flag(5)
      p% win_width = b% pg% History_Track_win_width(5)
      p% win_aspect_ratio = b% pg% History_Track_win_aspect_ratio(5)
      p% file_flag = b% pg% History_Track_file_flag(5)
      p% file_dir = b% pg% History_Track_file_dir(5)
      p% file_prefix = b% pg% History_Track_file_prefix(5)
      p% file_interval = b% pg% History_Track_file_interval(5)
      p% file_width = b% pg% History_Track_file_width(5)
      p% file_aspect_ratio = b% pg% History_Track_file_aspect_ratio(5)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Hist_Track6)
      p% plot => History_Track6_plot
      p% id = i_Binary_Hist_Track6
      p% name = 'History_Track6'
      p% win_flag = b% pg% History_Track_win_flag(6)
      p% win_width = b% pg% History_Track_win_width(6)
      p% win_aspect_ratio = b% pg% History_Track_win_aspect_ratio(6)
      p% file_flag = b% pg% History_Track_file_flag(6)
      p% file_dir = b% pg% History_Track_file_dir(6)
      p% file_prefix = b% pg% History_Track_file_prefix(6)
      p% file_interval = b% pg% History_Track_file_interval(6)
      p% file_width = b% pg% History_Track_file_width(6)
      p% file_aspect_ratio = b% pg% History_Track_file_aspect_ratio(6)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Hist_Track7)
      p% plot => History_Track7_plot
      p% id = i_Binary_Hist_Track7
      p% name = 'History_Track7'
      p% win_flag = b% pg% History_Track_win_flag(7)
      p% win_width = b% pg% History_Track_win_width(7)
      p% win_aspect_ratio = b% pg% History_Track_win_aspect_ratio(7)
      p% file_flag = b% pg% History_Track_file_flag(7)
      p% file_dir = b% pg% History_Track_file_dir(7)
      p% file_prefix = b% pg% History_Track_file_prefix(7)
      p% file_interval = b% pg% History_Track_file_interval(7)
      p% file_width = b% pg% History_Track_file_width(7)
      p% file_aspect_ratio = b% pg% History_Track_file_aspect_ratio(7)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Hist_Track8)
      p% plot => History_Track8_plot
      p% id = i_Binary_Hist_Track8
      p% name = 'History_Track8'
      p% win_flag = b% pg% History_Track_win_flag(8)
      p% win_width = b% pg% History_Track_win_width(8)
      p% win_aspect_ratio = b% pg% History_Track_win_aspect_ratio(8)
      p% file_flag = b% pg% History_Track_file_flag(8)
      p% file_dir = b% pg% History_Track_file_dir(8)
      p% file_prefix = b% pg% History_Track_file_prefix(8)
      p% file_interval = b% pg% History_Track_file_interval(8)
      p% file_width = b% pg% History_Track_file_width(8)
      p% file_aspect_ratio = b% pg% History_Track_file_aspect_ratio(8)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Hist_Track9)
      p% plot => History_Track9_plot
      p% id = i_Binary_Hist_Track9
      p% name = 'History_Track9'
      p% win_flag = b% pg% History_Track_win_flag(9)
      p% win_width = b% pg% History_Track_win_width(9)
      p% win_aspect_ratio = b% pg% History_Track_win_aspect_ratio(9)
      p% file_flag = b% pg% History_Track_file_flag(9)
      p% file_dir = b% pg% History_Track_file_dir(9)
      p% file_prefix = b% pg% History_Track_file_prefix(9)
      p% file_interval = b% pg% History_Track_file_interval(9)
      p% file_width = b% pg% History_Track_file_width(9)
      p% file_aspect_ratio = b% pg% History_Track_file_aspect_ratio(9)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Star_Hist_Track1)
      p% plot => Star_History_Track1_plot
      p% id = i_Binary_Star_Hist_Track1
      p% name = 'Star_History_Track1'
      p% win_flag = b% pg% Star_History_Track_win_flag(1)
      p% win_width = b% pg% Star_History_Track_win_width(1)
      p% win_aspect_ratio = b% pg% Star_History_Track_win_aspect_ratio(1)
      p% file_flag = b% pg% Star_History_Track_file_flag(1)
      p% file_dir = b% pg% Star_History_Track_file_dir(1)
      p% file_prefix = b% pg% Star_History_Track_file_prefix(1)
      p% file_interval = b% pg% Star_History_Track_file_interval(1)
      p% file_width = b% pg% Star_History_Track_file_width(1)
      p% file_aspect_ratio = b% pg% Star_History_Track_file_aspect_ratio(1)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Star_Hist_Track2)
      p% plot => Star_History_Track2_plot
      p% id = i_Binary_Star_Hist_Track2
      p% name = 'Star_History_Track2'
      p% win_flag = b% pg% Star_History_Track_win_flag(2)
      p% win_width = b% pg% Star_History_Track_win_width(2)
      p% win_aspect_ratio = b% pg% Star_History_Track_win_aspect_ratio(2)
      p% file_flag = b% pg% Star_History_Track_file_flag(2)
      p% file_dir = b% pg% Star_History_Track_file_dir(2)
      p% file_prefix = b% pg% Star_History_Track_file_prefix(2)
      p% file_interval = b% pg% Star_History_Track_file_interval(2)
      p% file_width = b% pg% Star_History_Track_file_width(2)
      p% file_aspect_ratio = b% pg% Star_History_Track_file_aspect_ratio(2)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Star_Hist_Track3)
      p% plot => Star_History_Track3_plot
      p% id = i_Binary_Star_Hist_Track3
      p% name = 'Star_History_Track3'
      p% win_flag = b% pg% Star_History_Track_win_flag(3)
      p% win_width = b% pg% Star_History_Track_win_width(3)
      p% win_aspect_ratio = b% pg% Star_History_Track_win_aspect_ratio(3)
      p% file_flag = b% pg% Star_History_Track_file_flag(3)
      p% file_dir = b% pg% Star_History_Track_file_dir(3)
      p% file_prefix = b% pg% Star_History_Track_file_prefix(3)
      p% file_interval = b% pg% Star_History_Track_file_interval(3)
      p% file_width = b% pg% Star_History_Track_file_width(3)
      p% file_aspect_ratio = b% pg% Star_History_Track_file_aspect_ratio(3)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Star_Hist_Track4)
      p% plot => Star_History_Track4_plot
      p% id = i_Binary_Star_Hist_Track4
      p% name = 'Star_History_Track4'
      p% win_flag = b% pg% Star_History_Track_win_flag(4)
      p% win_width = b% pg% Star_History_Track_win_width(4)
      p% win_aspect_ratio = b% pg% Star_History_Track_win_aspect_ratio(4)
      p% file_flag = b% pg% Star_History_Track_file_flag(4)
      p% file_dir = b% pg% Star_History_Track_file_dir(4)
      p% file_prefix = b% pg% Star_History_Track_file_prefix(4)
      p% file_interval = b% pg% Star_History_Track_file_interval(4)
      p% file_width = b% pg% Star_History_Track_file_width(4)
      p% file_aspect_ratio = b% pg% Star_History_Track_file_aspect_ratio(4)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Star_Hist_Track5)
      p% plot => Star_History_Track5_plot
      p% id = i_Binary_Star_Hist_Track5
      p% name = 'Star_History_Track5'
      p% win_flag = b% pg% Star_History_Track_win_flag(5)
      p% win_width = b% pg% Star_History_Track_win_width(5)
      p% win_aspect_ratio = b% pg% Star_History_Track_win_aspect_ratio(5)
      p% file_flag = b% pg% Star_History_Track_file_flag(5)
      p% file_dir = b% pg% Star_History_Track_file_dir(5)
      p% file_prefix = b% pg% Star_History_Track_file_prefix(5)
      p% file_interval = b% pg% Star_History_Track_file_interval(5)
      p% file_width = b% pg% Star_History_Track_file_width(5)
      p% file_aspect_ratio = b% pg% Star_History_Track_file_aspect_ratio(5)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Star_Hist_Track6)
      p% plot => Star_History_Track6_plot
      p% id = i_Binary_Star_Hist_Track6
      p% name = 'Star_History_Track6'
      p% win_flag = b% pg% Star_History_Track_win_flag(6)
      p% win_width = b% pg% Star_History_Track_win_width(6)
      p% win_aspect_ratio = b% pg% Star_History_Track_win_aspect_ratio(6)
      p% file_flag = b% pg% Star_History_Track_file_flag(6)
      p% file_dir = b% pg% Star_History_Track_file_dir(6)
      p% file_prefix = b% pg% Star_History_Track_file_prefix(6)
      p% file_interval = b% pg% Star_History_Track_file_interval(6)
      p% file_width = b% pg% Star_History_Track_file_width(6)
      p% file_aspect_ratio = b% pg% Star_History_Track_file_aspect_ratio(6)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Star_Hist_Track7)
      p% plot => Star_History_Track7_plot
      p% id = i_Binary_Star_Hist_Track7
      p% name = 'Star_History_Track7'
      p% win_flag = b% pg% Star_History_Track_win_flag(7)
      p% win_width = b% pg% Star_History_Track_win_width(7)
      p% win_aspect_ratio = b% pg% Star_History_Track_win_aspect_ratio(7)
      p% file_flag = b% pg% Star_History_Track_file_flag(7)
      p% file_dir = b% pg% Star_History_Track_file_dir(7)
      p% file_prefix = b% pg% Star_History_Track_file_prefix(7)
      p% file_interval = b% pg% Star_History_Track_file_interval(7)
      p% file_width = b% pg% Star_History_Track_file_width(7)
      p% file_aspect_ratio = b% pg% Star_History_Track_file_aspect_ratio(7)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Star_Hist_Track8)
      p% plot => Star_History_Track8_plot
      p% id = i_Binary_Star_Hist_Track8
      p% name = 'Star_History_Track8'
      p% win_flag = b% pg% Star_History_Track_win_flag(8)
      p% win_width = b% pg% Star_History_Track_win_width(8)
      p% win_aspect_ratio = b% pg% Star_History_Track_win_aspect_ratio(8)
      p% file_flag = b% pg% Star_History_Track_file_flag(8)
      p% file_dir = b% pg% Star_History_Track_file_dir(8)
      p% file_prefix = b% pg% Star_History_Track_file_prefix(8)
      p% file_interval = b% pg% Star_History_Track_file_interval(8)
      p% file_width = b% pg% Star_History_Track_file_width(8)
      p% file_aspect_ratio = b% pg% Star_History_Track_file_aspect_ratio(8)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Star_Hist_Track9)
      p% plot => Star_History_Track9_plot
      p% id = i_Binary_Star_Hist_Track9
      p% name = 'Star_History_Track9'
      p% win_flag = b% pg% Star_History_Track_win_flag(9)
      p% win_width = b% pg% Star_History_Track_win_width(9)
      p% win_aspect_ratio = b% pg% Star_History_Track_win_aspect_ratio(9)
      p% file_flag = b% pg% Star_History_Track_file_flag(9)
      p% file_dir = b% pg% Star_History_Track_file_dir(9)
      p% file_prefix = b% pg% Star_History_Track_file_prefix(9)
      p% file_interval = b% pg% Star_History_Track_file_interval(9)
      p% file_width = b% pg% Star_History_Track_file_width(9)
      p% file_aspect_ratio = b% pg% Star_History_Track_file_aspect_ratio(9)

      p => b% pg% pgbinary_win_file_ptr(i_Summary_Binary_History)
      p% plot => summary_history_plot
      p% id = i_Summary_Binary_History
      p% name = 'Summary_History'
      p% win_flag = b% pg% Summary_History_win_flag
      p% win_width = b% pg% Summary_History_win_width
      p% win_aspect_ratio = b% pg% Summary_History_win_aspect_ratio
      p% file_flag = b% pg% Summary_History_file_flag
      p% file_dir = b% pg% Summary_History_file_dir
      p% file_prefix = b% pg% Summary_History_file_prefix
      p% file_interval = b% pg% Summary_History_file_interval
      p% file_width = b% pg% Summary_History_file_width
      p% file_aspect_ratio = b% pg% Summary_History_file_aspect_ratio

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Grid1)
      p% plot => grid1_plot
      p% id = i_Binary_Grid1
      p% name = 'Grid1'
      p% win_flag = b% pg% Grid_win_flag(1)
      p% win_width = b% pg% Grid_win_width(1)
      p% win_aspect_ratio = b% pg% Grid_win_aspect_ratio(1)
      p% file_flag = b% pg% Grid_file_flag(1)
      p% file_dir = b% pg% Grid_file_dir(1)
      p% file_prefix = b% pg% Grid_file_prefix(1)
      p% file_interval = b% pg% Grid_file_interval(1)
      p% file_width = b% pg% Grid_file_width(1)
      p% file_aspect_ratio = b% pg% Grid_file_aspect_ratio(1)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Grid2)
      p% plot => grid2_plot
      p% id = i_Binary_Grid2
      p% name = 'Grid2'
      p% win_flag = b% pg% Grid_win_flag(2)
      p% win_width = b% pg% Grid_win_width(2)
      p% win_aspect_ratio = b% pg% Grid_win_aspect_ratio(2)
      p% file_flag = b% pg% Grid_file_flag(2)
      p% file_dir = b% pg% Grid_file_dir(2)
      p% file_prefix = b% pg% Grid_file_prefix(2)
      p% file_interval = b% pg% Grid_file_interval(2)
      p% file_width = b% pg% Grid_file_width(2)
      p% file_aspect_ratio = b% pg% Grid_file_aspect_ratio(2)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Grid3)
      p% plot => grid3_plot
      p% id = i_Binary_Grid3
      p% name = 'Grid3'
      p% win_flag = b% pg% Grid_win_flag(3)
      p% win_width = b% pg% Grid_win_width(3)
      p% win_aspect_ratio = b% pg% Grid_win_aspect_ratio(3)
      p% file_flag = b% pg% Grid_file_flag(3)
      p% file_dir = b% pg% Grid_file_dir(3)
      p% file_prefix = b% pg% Grid_file_prefix(3)
      p% file_interval = b% pg% Grid_file_interval(3)
      p% file_width = b% pg% Grid_file_width(3)
      p% file_aspect_ratio = b% pg% Grid_file_aspect_ratio(3)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Grid4)
      p% plot => grid4_plot
      p% id = i_Binary_Grid4
      p% name = 'Grid4'
      p% win_flag = b% pg% Grid_win_flag(4)
      p% win_width = b% pg% Grid_win_width(4)
      p% win_aspect_ratio = b% pg% Grid_win_aspect_ratio(4)
      p% file_flag = b% pg% Grid_file_flag(4)
      p% file_dir = b% pg% Grid_file_dir(4)
      p% file_prefix = b% pg% Grid_file_prefix(4)
      p% file_interval = b% pg% Grid_file_interval(4)
      p% file_width = b% pg% Grid_file_width(4)
      p% file_aspect_ratio = b% pg% Grid_file_aspect_ratio(4)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Grid5)
      p% plot => grid5_plot
      p% id = i_Binary_Grid5
      p% name = 'Grid5'
      p% win_flag = b% pg% Grid_win_flag(5)
      p% win_width = b% pg% Grid_win_width(5)
      p% win_aspect_ratio = b% pg% Grid_win_aspect_ratio(5)
      p% file_flag = b% pg% Grid_file_flag(5)
      p% file_dir = b% pg% Grid_file_dir(5)
      p% file_prefix = b% pg% Grid_file_prefix(5)
      p% file_interval = b% pg% Grid_file_interval(5)
      p% file_width = b% pg% Grid_file_width(5)
      p% file_aspect_ratio = b% pg% Grid_file_aspect_ratio(5)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Grid6)
      p% plot => grid6_plot
      p% id = i_Binary_Grid6
      p% name = 'Grid6'
      p% win_flag = b% pg% Grid_win_flag(6)
      p% win_width = b% pg% Grid_win_width(6)
      p% win_aspect_ratio = b% pg% Grid_win_aspect_ratio(6)
      p% file_flag = b% pg% Grid_file_flag(6)
      p% file_dir = b% pg% Grid_file_dir(6)
      p% file_prefix = b% pg% Grid_file_prefix(6)
      p% file_interval = b% pg% Grid_file_interval(6)
      p% file_width = b% pg% Grid_file_width(6)
      p% file_aspect_ratio = b% pg% Grid_file_aspect_ratio(6)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Grid7)
      p% plot => grid7_plot
      p% id = i_Binary_Grid7
      p% name = 'Grid7'
      p% win_flag = b% pg% Grid_win_flag(7)
      p% win_width = b% pg% Grid_win_width(7)
      p% win_aspect_ratio = b% pg% Grid_win_aspect_ratio(7)
      p% file_flag = b% pg% Grid_file_flag(7)
      p% file_dir = b% pg% Grid_file_dir(7)
      p% file_prefix = b% pg% Grid_file_prefix(7)
      p% file_interval = b% pg% Grid_file_interval(7)
      p% file_width = b% pg% Grid_file_width(7)
      p% file_aspect_ratio = b% pg% Grid_file_aspect_ratio(7)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Grid8)
      p% plot => grid8_plot
      p% id = i_Binary_Grid8
      p% name = 'Grid8'
      p% win_flag = b% pg% Grid_win_flag(8)
      p% win_width = b% pg% Grid_win_width(8)
      p% win_aspect_ratio = b% pg% Grid_win_aspect_ratio(8)
      p% file_flag = b% pg% Grid_file_flag(8)
      p% file_dir = b% pg% Grid_file_dir(8)
      p% file_prefix = b% pg% Grid_file_prefix(8)
      p% file_interval = b% pg% Grid_file_interval(8)
      p% file_width = b% pg% Grid_file_width(8)
      p% file_aspect_ratio = b% pg% Grid_file_aspect_ratio(8)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Grid9)
      p% plot => grid9_plot
      p% id = i_Binary_Grid9
      p% name = 'Grid9'
      p% win_flag = b% pg% Grid_win_flag(9)
      p% win_width = b% pg% Grid_win_width(9)
      p% win_aspect_ratio = b% pg% Grid_win_aspect_ratio(9)
      p% file_flag = b% pg% Grid_file_flag(9)
      p% file_dir = b% pg% Grid_file_dir(9)
      p% file_prefix = b% pg% Grid_file_prefix(9)
      p% file_interval = b% pg% Grid_file_interval(9)
      p% file_width = b% pg% Grid_file_width(9)
      p% file_aspect_ratio = b% pg% Grid_file_aspect_ratio(9)

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Star1)
      p% plot => Star1_plot
      p% id = i_Binary_Star1
      p% name = 'Star1'
      p% win_flag = b% pg% Star1_win_flag
      p% win_width = b% pg% Star1_win_width
      p% win_aspect_ratio = b% pg% Star1_win_aspect_ratio
      p% file_flag = b% pg% Star1_file_flag
      p% file_dir = b% pg% Star1_file_dir
      p% file_prefix = b% pg% Star1_file_prefix
      p% file_interval = b% pg% Star1_file_interval
      p% file_width = b% pg% Star1_file_width
      p% file_aspect_ratio = b% pg% Star1_file_aspect_ratio

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Star2)
      p% plot => Star2_plot
      p% id = i_Binary_Star2
      p% name = 'Star2'
      p% win_flag = b% pg% Star2_win_flag
      p% win_width = b% pg% Star2_win_width
      p% win_aspect_ratio = b% pg% Star2_win_aspect_ratio
      p% file_flag = b% pg% Star2_file_flag
      p% file_dir = b% pg% Star2_file_dir
      p% file_prefix = b% pg% Star2_file_prefix
      p% file_interval = b% pg% Star2_file_interval
      p% file_width = b% pg% Star2_file_width
      p% file_aspect_ratio = b% pg% Star2_file_aspect_ratio

      p => b% pg% pgbinary_win_file_ptr(i_Binary_Orbit)
      p% plot => Orbit_plot
      p% id = i_Binary_Orbit
      p% name = 'Orbit'
      p% win_flag = b% pg% Orbit_win_flag
      p% win_width = b% pg% Orbit_win_width
      p% win_aspect_ratio = b% pg% Orbit_win_aspect_ratio
      p% file_flag = b% pg% Orbit_file_flag
      p% file_dir = b% pg% Orbit_file_dir
      p% file_prefix = b% pg% Orbit_file_prefix
      p% file_interval = b% pg% Orbit_file_interval
      p% file_width = b% pg% Orbit_file_width
      p% file_aspect_ratio = b% pg% Orbit_file_aspect_ratio

      do i = 1, max_num_Binary_Other_plots
         p => b% pg% pgbinary_win_file_ptr(i_Binary_Other + i - 1)
         p% win_flag = .false.
         p% file_flag = .false.
         p% okay_to_call_do_plot_in_binary_grid = .false.
      end do

      if (b% use_other_pgbinary_plots) &
         call b% other_pgbinary_plots_info(b% binary_id, ierr)

   end subroutine set_win_file_data


   subroutine do_pgbinary_plots(b, must_write_files, ierr)
      type (binary_info), pointer :: b
      logical, intent(in) :: must_write_files
      integer, intent(out) :: ierr

      integer :: i
      integer(8) :: time0, time1, clock_rate
      logical :: pause, fexists

      include 'formats'

      ierr = 0

      if (b% pg% clear_history) call pgbinary_clear(b)

      call update_pgbinary_data(b, ierr)
      if (failed('update_pgbinary_data')) return
      ! update pgstar data if stars present
      if (b% point_mass_i /= 1) call update_pgstar_data(b% s1, ierr)
      if (b% point_mass_i /= 2) call update_pgstar_data(b% s2, ierr)
      call onScreen_Plots(b, must_write_files, ierr)
      if (failed('onScreen_Plots')) return
      call update_pgbinary_history_file(b, ierr)
      if (failed('save_text_data')) return
      ! update pgstar data if stars present
      if (b% have_star_1) call update_pgstar_history_file(b% s1, ierr)
      if (b% have_star_2) call update_pgstar_history_file(b% s2, ierr)
      pause = b% pg% pause
      if ((.not. pause) .and. b% pg% pause_interval > 0) &
         pause = (mod(b% model_number, b% pg% pause_interval) == 0)
      if (pause) then
         write(*, *)
         write(*, *) 'model_number', b% model_number
         write(*, *) 'pgbinary: paused -- hit RETURN to continue'
         read(*, *)
      end if

      if (b% pg% pgbinary_sleep > 0) then
         time0 = b% system_clock_at_start_of_step
         do
            call system_clock(time1, clock_rate)
            if (dble(time1 - time0) / dble(clock_rate) >= b% pg% pgbinary_sleep) exit
         end do
      end if

      !write(*,2) 'pgbinary: done', b% model_number

   contains

      logical function failed(str)
         character (len = *), intent(in) :: str
         failed = (ierr /= 0)
         if (failed) then
            write(*, *) trim(str) // ' ierr', ierr
         end if
      end function failed

   end subroutine do_pgbinary_plots


   ! pgbinary driver, called after each timestep
   subroutine onScreen_Plots(b, must_write_files_in, ierr)
      use utils_lib

      type (binary_info), pointer :: b
      logical :: must_write_files_in
      integer, intent(out) :: ierr

      integer :: i
      type (pgbinary_win_file_data), pointer :: p
      logical, parameter :: dbg = .false.
      real(dp) :: dlgL, dlgTeff, dHR
      logical :: must_write_files, show_plot_now, save_plot_now

      include 'formats'
      ierr = 0

      ! initialize pgbinary
      if (.not. have_initialized_pgbinary) then
         call init_pgbinary(ierr)
         if (failed('init_pgbinary')) return
      end if

      ! request files if sufficient movement in HR diagram
      must_write_files = must_write_files_in

      show_plot_now = .false.
      if (b% pg% pgbinary_interval > 0) then
         if(mod(b% model_number, b% pg% pgbinary_interval) == 0) then
            show_plot_now = .true.
         end if
      end if

      ! loop through all plots
      do i = 1, num_pgbinary_plots
         p => b% pg% pgbinary_win_file_ptr(i)
         if(show_plot_now) then
            ! call to check_window opens device
            call check_window(b, p, ierr)
            if (failed('check_window')) return

            ! make the plot (window)
            if (p% do_win) then
               call p% plot(b% binary_id, p% id_win, ierr)
               if (failed(p% name)) return
            end if
         end if

         save_plot_now = must_write_files
         if (p% file_interval > 0) then
            if(mod(b% model_number, p% file_interval) == 0) then
               save_plot_now = .true.
            end if
         end if

         if (save_plot_now) then
            ! call to check_file opens device and does mkdir
            call check_file(b, p, ierr)

            ! make the plot (file)
            if (p% do_file) then
               call p% plot(b% binary_id, p% id_file, ierr)
               if (failed(p% name)) return
               call pgclos
               if (b% pg% pgbinary_report_writing_files) &
                  write(*, *) trim(p% most_recent_filename)
               p% id_file = 0
               p% do_file = .false.
            end if
         end if
      end do

   contains

      logical function failed(str)
         character (len = *), intent(in) :: str
         failed = (ierr /= 0)
         if (failed) then
            write(*, *) trim(str) // ' ierr', ierr
         end if
      end function failed

   end subroutine onScreen_Plots


   subroutine update_pgbinary_history_file(b, ierr)
      use utils_lib
      type (binary_info), pointer :: b
      integer, intent(out) :: ierr

      integer :: iounit, i, n
      character (len = 1024) :: fname
      type (pgbinary_hist_node), pointer :: pg

      logical, parameter :: dbg = .false.

      include 'formats'

      ierr = 0
      pg => b% pg% pgbinary_hist
      if (.not. associated(pg)) return

      n = b% number_of_binary_history_columns
      fname = trim(b% photo_directory) // '/pgbinary.dat'

      if (associated(pg% next)) then
         open(newunit = iounit, file = trim(fname), action = 'write', &
            position = 'append', form = 'unformatted', iostat = ierr)
      else
         open(newunit = iounit, file = trim(fname), action = 'write', &
            status = 'replace', form = 'unformatted', iostat = ierr)
         if (ierr == 0) write(iounit) n
      end if
      if (ierr /= 0) then
         write(*, *) 'save_pgbinary_data: cannot open new file'
         return
      end if

      if (associated(pg% vals)) then
         if (size(pg% vals, dim = 1) >= n) then
            write(iounit) pg% age, pg% step, pg% vals(1:n)
         end if
      end if

      close(iounit)

   end subroutine update_pgbinary_history_file


   subroutine read_pgbinary_data(b, ierr)
      use utils_lib
      type (binary_info), pointer :: b
      integer, intent(out) :: ierr

      logical :: fexist
      integer :: iounit, i, n
      character (len = 1024) :: fname
      type (pgbinary_hist_node), pointer :: pg

      logical, parameter :: dbg = .false.

      include 'formats'
      ierr = 0

      fname = trim(b% photo_directory) // '/pgbinary.dat'
      inquire(file = trim(fname), exist = fexist)
      if (.not.fexist) then
         if (dbg) write(*, *) 'failed to find ' // trim(fname)
         return
      end if

      open(newunit = iounit, file = trim(fname), action = 'read', &
         status = 'old', iostat = ierr, form = 'unformatted')
      if (ierr /= 0) then
         if (dbg) write(*, *) 'failed to open ' // trim(fname)
         return
      end if

      read(iounit, iostat = ierr) n
      if (ierr == 0) then
         if (b% number_of_binary_history_columns < 0) then
            b% number_of_binary_history_columns = n
         else if (b% number_of_binary_history_columns /= n) then
            ierr = -1
         end if
      end if

      if (ierr /= 0) then
         write(*, *) 'failed read pgbinary history ' // trim(fname)
      else
         do ! keep reading until reach end of file so take care of restarts
            allocate(pg)
            allocate(pg% vals(n))
            read(iounit, iostat = ierr) pg% age, pg% step, pg% vals(1:n)
            if (ierr /= 0) then
               ierr = 0
               deallocate(pg% vals)
               deallocate(pg)
               exit
            end if
            call add_to_pgbinary_hist(b, pg)
         end do
      end if

      close(iounit)

   end subroutine read_pgbinary_data


   subroutine update_pgbinary_data(b, ierr)

      type (binary_info), pointer :: b
      integer, intent(out) :: ierr

      integer :: num, i
      type (pgbinary_hist_node), pointer :: pg

      include 'formats'

      ierr = 0

      allocate(pg)
      pg% step = b% model_number
      pg% age = b% binary_age
      num = b% number_of_binary_history_columns
      allocate(pg% vals(num))
      call get_hist_values(num, ierr)
      if (ierr /= 0) then
         write(*, *) 'failed in get_hist_values'
         return
         stop 'pgbinary'
      end if
      call add_to_pgbinary_hist(b, pg)

   contains


      subroutine get_hist_values(num, ierr)
         use binary_history, only: do_get_data_for_binary_history_columns
         integer, intent(in) :: num
         integer, intent(out) :: ierr
         integer :: i
         ierr = 0
         if (b% need_to_set_binary_history_names_etc .or. &
            b% model_number_of_binary_history_values /= b% model_number) then
            call do_get_data_for_binary_history_columns(b, ierr)
            if (ierr /= 0) return
         end if
         do i = 1, num
            pg% vals(i) = b% binary_history_values(i)
         end do
      end subroutine get_hist_values


   end subroutine update_pgbinary_data

   subroutine shutdown_pgbinary(b)
      use pgbinary_support
      type (binary_info), pointer :: b

      call pgbinary_clear(b)

      have_initialized_pgbinary = .false.

   end subroutine shutdown_pgbinary

end module pgbinary
